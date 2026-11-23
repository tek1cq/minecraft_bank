local ROOT = "bank_data"
local ACCOUNTS = ROOT .. "/accounts.db"
local HISTORY = ROOT .. "/transactions.db"

local function load(path)
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = textutils.unserialize(f.readAll())
    f.close()
    return data
end

local function save(path, data)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(data))
    f.close()
end

local function pause()
    print("")
    print("Press ENTER to continue...")
    read()
end

local function getAccount(db, id)
    return db.accounts[tostring(id)]
end

local function log(action, id, amount, details)
    local history = load(HISTORY) or {}
    table.insert(history, {
        time = os.epoch("utc"),
        action = action,
        id = id,
        amount = amount,
        details = details
    })
    save(HISTORY, history)
end

local function inputNumber(message)
    write(message)
    local value = tonumber(read())
    if not value or value % 1 ~= 0 or value < 1 then
        print("Invalid number.")
        return nil
    end
    return value
end


local REGISTRATIONS = ROOT .. "/registration_codes.db"

local function loadRegistrations()
    return load(REGISTRATIONS) or {codes = {}}
end

local function createAccount()
    local accounts = load(ACCOUNTS)
    local registrations = loadRegistrations()
    if not accounts or type(accounts.accounts) ~= "table" then
        print("Account database unavailable.")
        return
    end
    write("Minecraft nickname: ")
    local nickname = read()
    nickname = nickname:match("^%s*(.-)%s*$")
    if #nickname < 3 or #nickname > 20 then
        print("Nickname must be 3-20 characters.")
        return
    end
    for _, account in pairs(accounts.accounts) do
        if account.name:lower() == nickname:lower() then
            print("This nickname already has an account.")
            return
        end
    end
    for _, item in pairs(registrations.codes) do
        if item.nickname:lower() == nickname:lower() then
            print("A code already exists for this nickname.")
            return
        end
    end
    local alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code
    repeat
        local parts = {}
        for i = 1, 8 do
            local index = math.random(#alphabet)
            parts[i] = alphabet:sub(index, index)
        end
        local raw = table.concat(parts)
        code = raw:sub(1, 4) .. "-" .. raw:sub(5, 8)
    until not registrations.codes[code]
    local id = accounts.nextId or 1
    accounts.nextId = id + 1
    registrations.codes[code] = {
        id = id,
        nickname = nickname,
        used = false,
        revoked = false,
        createdAt = os.epoch("utc")
    }
    save(ACCOUNTS, accounts)
    save(REGISTRATIONS, registrations)
    print("")
    print("ACCOUNT RESERVED")
    print("Player: " .. nickname)
    print("Bank ID: " .. id)
    print("Registration code: " .. code)
    print("Give this code to the player.")
end

local function showRegistrationCodes()
    local registrations = loadRegistrations()
    print("=== REGISTRATION CODES ===")
    local count = 0
    for code, item in pairs(registrations.codes) do
        count = count + 1
        local status = item.used and "USED" or (item.revoked and "REVOKED" or "UNUSED")
        print(code .. " | ID: " .. item.id .. " | " .. item.nickname .. " | " .. status)
    end
    if count == 0 then
        print("No registration codes.")
    end
end

local function revokeRegistrationCode()
    local registrations = loadRegistrations()
    write("Registration code: ")
    local code = read():upper()
    local item = registrations.codes[code]
    if not item then
        print("Code not found.")
        return
    end
    if item.used then
        print("This code has already been used.")
        return
    end
    if item.revoked then
        print("This code is already revoked.")
        return
    end
    item.revoked = true
    item.revokedAt = os.epoch("utc")
    save(REGISTRATIONS, registrations)
    print("Code revoked.")
end

math.randomseed(os.epoch("utc") % 2147483647)

local function findPlayer()
    local db = load(ACCOUNTS)
    write("Bank ID: ")
    local id = read()
    local account = getAccount(db, id)
    if not account then
        print("Account not found.")
        return
    end
    print("")
    print("ID: " .. account.id)
    print("Player: " .. account.name)
    print("Balance: " .. account.balance .. " BC")
    print("Blocked: " .. tostring(account.blocked))
end

local function changeBalance(mode)
    local db = load(ACCOUNTS)
    write("Player Bank ID: ")
    local id = read()
    local account = getAccount(db, id)
    if not account then
        print("Account not found.")
        return
    end
    local amount = inputNumber("Amount BC: ")
    if not amount then return end
    if mode == "REMOVE" and account.balance < amount then
        print("Insufficient balance.")
        return
    end
    if mode == "ADD" then
        account.balance = account.balance + amount
    else
        account.balance = account.balance - amount
    end
    save(ACCOUNTS, db)
    log("ADMIN_" .. mode, account.id, amount, "Administrator adjustment")
    print("Operation successful.")
    print("New balance: " .. account.balance .. " BC")
end

local function toggleBlock()
    local db = load(ACCOUNTS)
    write("Player Bank ID: ")
    local id = read()
    local account = getAccount(db, id)
    if not account then
        print("Account not found.")
        return
    end
    account.blocked = not account.blocked
    save(ACCOUNTS, db)
    log("ADMIN_BLOCK", account.id, 0, tostring(account.blocked))
    print("Blocked: " .. tostring(account.blocked))
end

local function showHistory()
    local history = load(HISTORY) or {}
    print("=== LAST TRANSACTIONS ===")
    for i = math.max(1, #history - 14), #history do
        local item = history[i]
        print(
            tostring(item.action) ..
            " | ID: " .. tostring(item.id or item.from) ..
            " | Amount: " .. tostring(item.amount)
        )
    end
end

local function showStatistics()
    local db = load(ACCOUNTS)
    local count = 0
    local total = 0
    for _, account in pairs(db.accounts) do
        count = count + 1
        total = total + account.balance
    end
    print("Registered accounts: " .. count)
    print("Total money in circulation: " .. total .. " BC")
end

while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("================================")
    print("          BANK ADMIN")
    print("================================")
    print("1. Find account by ID")
    print("2. Add money")
    print("3. Remove money")
    print("4. Block / unblock account")
    print("5. Transaction history")
    print("6. Bank statistics")
    print("7. Create account")
    print("8. Registration codes")
    print("9. Revoke registration code")
    print("0. Exit")
    print("--------------------------------")
    write("Select: ")
    local choice = read()
    term.clear()
    term.setCursorPos(1, 1)
    if choice == "1" then
        findPlayer()
        pause()
    elseif choice == "2" then
        changeBalance("ADD")
        pause()
    elseif choice == "3" then
        changeBalance("REMOVE")
        pause()
    elseif choice == "4" then
        toggleBlock()
        pause()
    elseif choice == "5" then
        showHistory()
        pause()
    elseif choice == "6" then
        showStatistics()
        pause()
    elseif choice == "7" then
        createAccount()
        pause()
    elseif choice == "8" then
        showRegistrationCodes()
        pause()
    elseif choice == "9" then
        revokeRegistrationCode()
        pause()
    elseif choice == "0" then
        break
    else
        print("Invalid selection.")
        pause()
    end
end
