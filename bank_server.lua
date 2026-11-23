local DATA = "bank_data"
local ACCOUNTS = DATA .. "/accounts.db"
local HISTORY = DATA .. "/transactions.db"
local SETTINGS = DATA .. "/settings.db"
local REGISTRATIONS = DATA .. "/registration_codes.db"
local PROTOCOL = "bank"
term.clear()
term.setCursorPos(1, 1)

local function load(path, fallback)
    if not fs.exists(path) then
        return fallback
    end
    local file = fs.open(path, "r")
    local content = file.readAll()
    file.close()
    local ok, result = pcall(textutils.unserialize, content)
    if ok and type(result) == "table" then
        return result
    end
    error("Database error: " .. path)
end

local function save(path, data)
    local file = fs.open(path, "w")
    file.write(textutils.serialize(data))
    file.close()
end
local accounts = load(ACCOUNTS, {
    nextId = 100001,
    accounts = {}
})
local history = load(HISTORY, {})
local registrations = load(REGISTRATIONS, {codes = {}})
local settings = load(SETTINGS, {
    startingBalance = 500,
    currency = "BC",
    bankName = "Bank"
})

local function findAccount(id)
    return accounts.accounts[tostring(id)]
end

local function log(action, from, to, amount)
    table.insert(history, {
        time = os.epoch("utc"),
        action = action,
        from = from,
        to = to,
        amount = amount
    })
    save(HISTORY, history)
end

local function reply(sender, data)
    rednet.send(sender, data, PROTOCOL)
end

local ADMIN_CONFIG = DATA .. "/admin_settings.db"
local adminConfig = load(ADMIN_CONFIG, {password = nil})
local adminSessions = {}

local function adminAuthorized(sender, request)
    return type(request.token) == "string"
        and adminSessions[sender] == request.token
end

local function handle(sender, request)
    if type(request) ~= "table" then
        return {ok = false, error = "INVALID REQUEST"}
    end
    if request.action == "REGISTER" then
        local code = request.code
        local pin = request.pin
        if type(code) ~= "string" then
            return {ok = false, error = "INVALID REGISTRATION CODE"}
        end
        code = code:upper()
        local registration = registrations.codes[code]
        if not registration or registration.used or registration.revoked then
            return {ok = false, error = "INVALID REGISTRATION CODE"}
        end
        if type(pin) ~= "string" or not pin:match("^%d%d%d%d%d%d$") then
            return {ok = false, error = "PIN MUST BE 6 DIGITS"}
        end
        local id = registration.id
        local name = registration.nickname
        if findAccount(id) then
            return {ok = false, error = "ACCOUNT ALREADY EXISTS"}
        end
        registration.used = true
        registration.usedAt = os.epoch("utc")
        accounts.accounts[tostring(id)] = {
            id = id,
            name = name,
            pin = pin,
            balance = settings.startingBalance,
            blocked = false,
            created = os.epoch("utc")
        }
        save(ACCOUNTS, accounts)
        save(REGISTRATIONS, registrations)
        log("REGISTER", nil, id, settings.startingBalance)
        return {
            ok = true,
            message = "ACCOUNT CREATED",
            id = id,
            name = name,
            balance = settings.startingBalance,
            created = findAccount(id).created
        }
    end
    if request.action == "CHECK_ID" then
        local account = findAccount(request.id)
        if not account then
            return {ok = false, error = "ACCOUNT NOT FOUND"}
        end
        return {ok = true}
    end
    if request.action == "CHECK_NAME" then
        local name = request.name
        if type(name) ~= "string" or #name < 3 or #name > 20 then
            return {ok = false, error = "INVALID NAME"}
        end
        for _, account in pairs(accounts.accounts) do
            if account.name:lower() == name:lower() then
                return {ok = false, error = "NAME ALREADY REGISTERED"}
            end
        end
        return {ok = true}
    end
    if request.action == "BALANCE" then
        local account = findAccount(request.id)
        if not account or account.pin ~= request.pin then
            return {ok = false, error = "INVALID ID OR PIN"}
        end
        if account.blocked then
            return {ok = false, error = "ACCOUNT BLOCKED"}
        end
        return {
            ok = true,
            id = account.id,
            name = account.name,
            balance = account.balance,
            created = account.created
        }
    end
    if request.action == "NOTIFICATIONS" then
        local account = findAccount(request.id)
        if not account or account.pin ~= request.pin then
            return {ok = false, error = "INVALID ID OR PIN"}
        end
        if account.blocked then
            return {ok = false, error = "ACCOUNT BLOCKED"}
        end
        local result = {}
        for index = #history, 1, -1 do
            local entry = history[index]
            if entry.action == "TRANSFER" and tostring(entry.to) == tostring(account.id) then
                local senderAccount = findAccount(entry.from)
                result[#result + 1] = {
                    time = entry.time,
                    action = entry.action,
                    from = entry.from,
                    to = entry.to,
                    amount = entry.amount,
                    otherName = senderAccount and senderAccount.name or tostring(entry.from)
                }
                if #result >= 40 then
                    break
                end
            end
        end
        return {ok = true, transactions = result}
    end
    if request.action == "HISTORY" then
        local account = findAccount(request.id)
        if not account or account.pin ~= request.pin then
            return {ok = false, error = "INVALID ID OR PIN"}
        end
        if account.blocked then
            return {ok = false, error = "ACCOUNT BLOCKED"}
        end
        local result = {}
        for index = #history, 1, -1 do
            local entry = history[index]
            if tostring(entry.from) == tostring(account.id)
                or tostring(entry.to) == tostring(account.id) then
                local item = {
                    time = entry.time,
                    action = entry.action,
                    from = entry.from,
                    to = entry.to,
                    amount = entry.amount
                }
                if entry.action == "REGISTER" then
                    item.otherName = "Bank"
                else
                    local otherId = tostring(entry.from) == tostring(account.id) and entry.to or entry.from
                    local otherAccount = findAccount(otherId)
                    item.otherName = otherAccount and otherAccount.name or tostring(otherId)
                end
                result[#result + 1] = item
                if #result >= 40 then
                    break
                end
            end
        end
        return {ok = true, transactions = result}
    end
    if request.action == "LOOKUP_RECIPIENT" then
        local senderAccount = findAccount(request.id)
        if not senderAccount or senderAccount.pin ~= request.pin then
            return {ok = false, error = "INVALID ID OR PIN"}
        end
        if senderAccount.blocked then
            return {ok = false, error = "ACCOUNT BLOCKED"}
        end
        if type(request.recipient) ~= "string" or request.recipient == "" then
            return {ok = false, error = "RECIPIENT NOT FOUND"}
        end
        local recipient = nil
        local numericId = tonumber(request.recipient)
        if numericId and numericId >= 1 and numericId % 1 == 0 then
            recipient = findAccount(numericId)
        else
            local searchName = request.recipient:lower()
            for _, candidate in pairs(accounts.accounts) do
                if type(candidate.name) == "string" and candidate.name:lower() == searchName then
                    recipient = candidate
                    break
                end
            end
        end
        if not recipient then
            return {ok = false, error = "RECIPIENT NOT FOUND"}
        end
        if recipient.blocked then
            return {ok = false, error = "RECIPIENT BLOCKED"}
        end
        if tostring(recipient.id) == tostring(senderAccount.id) then
            return {ok = false, error = "CANNOT TRANSFER TO YOURSELF"}
        end
        return {
            ok = true,
            id = recipient.id,
            name = recipient.name
        }
    end
    if request.action == "TRANSFER" then
        local senderAccount = findAccount(request.id)
        local receiverAccount = findAccount(request.target)
        local amount = request.amount
        if not senderAccount or senderAccount.pin ~= request.pin then
            return {ok = false, error = "INVALID ID OR PIN"}
        end
        if senderAccount.blocked then
            return {ok = false, error = "ACCOUNT BLOCKED"}
        end
        if not receiverAccount or receiverAccount.blocked then
            return {ok = false, error = "RECIPIENT NOT FOUND OR BLOCKED"}
        end
        if type(amount) ~= "number" or amount < 1 or amount % 1 ~= 0 then
            return {ok = false, error = "INVALID AMOUNT"}
        end
        if senderAccount.id == receiverAccount.id then
            return {ok = false, error = "CANNOT TRANSFER TO YOURSELF"}
        end
        if senderAccount.balance < amount then
            return {ok = false, error = "NOT ENOUGH MONEY"}
        end
        senderAccount.balance = senderAccount.balance - amount
        receiverAccount.balance = receiverAccount.balance + amount
        save(ACCOUNTS, accounts)
        log("TRANSFER", senderAccount.id, receiverAccount.id, amount)
        return {ok = true, message = "TRANSFER COMPLETE"}
    end
    if request.action == "ADMIN_LOGIN" then
        if type(adminConfig.password) ~= "string" or adminConfig.password == "" then
            return {ok = false, error = "ADMIN PASSWORD NOT CONFIGURED"}
        end
        if type(request.password) ~= "string" or request.password ~= adminConfig.password then
            return {ok = false, error = "INCORRECT PASSWORD"}
        end
        local token = tostring(os.epoch("utc")) .. "-" .. tostring(math.random(100000, 999999))
        adminSessions[sender] = token
        return {ok = true, token = token}
    end
    if type(request.action) == "string" and request.action:match("^ADMIN_") then
        if not adminAuthorized(sender, request) then
            return {ok = false, error = "ADMIN LOGIN REQUIRED"}
        end
        if request.action == "ADMIN_STATS" then
            local count, total, blocked = 0, 0, 0
            for _, account in pairs(accounts.accounts) do
                count = count + 1
                total = total + (tonumber(account.balance) or 0)
                if account.blocked then blocked = blocked + 1 end
            end
            return {ok = true, accounts = count, total = total, blocked = blocked}
        end
        if request.action == "ADMIN_ACCOUNT" then
            local account = findAccount(request.id)
            if not account then return {ok = false, error = "ACCOUNT NOT FOUND"} end
            return {ok = true, id = account.id, name = account.name, balance = account.balance, blocked = account.blocked, created = account.created}
        end
        if request.action == "ADMIN_ADJUST" then
            local account = findAccount(request.id)
            local amount = tonumber(request.amount)
            if not account then return {ok = false, error = "ACCOUNT NOT FOUND"} end
            if not amount or amount < 1 or amount % 1 ~= 0 then return {ok = false, error = "INVALID AMOUNT"} end
            if request.mode == "REMOVE" and account.balance < amount then return {ok = false, error = "INSUFFICIENT BALANCE"} end
            if request.mode == "ADD" then account.balance = account.balance + amount
            elseif request.mode == "REMOVE" then account.balance = account.balance - amount
            else return {ok = false, error = "INVALID OPERATION"} end
            save(ACCOUNTS, accounts)
            log("ADMIN_" .. request.mode, account.id, nil, amount)
            return {ok = true, balance = account.balance}
        end
        if request.action == "ADMIN_TOGGLE_BLOCK" then
            local account = findAccount(request.id)
            if not account then return {ok = false, error = "ACCOUNT NOT FOUND"} end
            account.blocked = not account.blocked
            save(ACCOUNTS, accounts)
            log(account.blocked and "ADMIN_BLOCK" or "ADMIN_UNBLOCK", account.id, nil, nil)
            return {ok = true, blocked = account.blocked}
        end
        if request.action == "ADMIN_HISTORY" then
            local result = {}
            for index = #history, 1, -1 do
                local entry = history[index]
                if request.id == "*" or tostring(entry.from) == tostring(request.id) or tostring(entry.to) == tostring(request.id)
                    or tostring(entry.id) == tostring(request.id) then
                    local item = {
                        time = entry.time,
                        action = entry.action,
                        from = entry.from,
                        to = entry.to,
                        amount = entry.amount
                    }
                    local fromAccount = entry.from and findAccount(entry.from)
                    local toAccount = entry.to and findAccount(entry.to)
                    item.fromName = fromAccount and fromAccount.name or (entry.from and tostring(entry.from) or nil)
                    item.toName = toAccount and toAccount.name or (entry.to and tostring(entry.to) or nil)
                    result[#result + 1] = item
                    if #result >= 40 then break end
                end
            end
            return {ok = true, transactions = result}
        end
        if request.action == "ADMIN_CREATE_ACCOUNT" then
            local nickname = request.nickname
            if type(nickname) ~= "string" then return {ok = false, error = "INVALID NICKNAME"} end
            nickname = nickname:match("^%s*(.-)%s*$")
            if #nickname < 3 or #nickname > 20 then return {ok = false, error = "NICKNAME MUST BE 3-20 CHARACTERS"} end
            for _, account in pairs(accounts.accounts) do
                if type(account.name) == "string" and account.name:lower() == nickname:lower() then
                    return {ok = false, error = "NICKNAME ALREADY REGISTERED"}
                end
            end
            for _, item in pairs(registrations.codes) do
                if type(item.nickname) == "string" and item.nickname:lower() == nickname:lower() and not item.used and not item.revoked then
                    return {ok = false, error = "ACTIVE CODE ALREADY EXISTS"}
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
            registrations.codes[code] = {id = id, nickname = nickname, used = false, revoked = false, createdAt = os.epoch("utc")}
            save(ACCOUNTS, accounts)
            save(REGISTRATIONS, registrations)
            return {ok = true, id = id, nickname = nickname, code = code}
        end
        if request.action == "ADMIN_CODES" then
            local result = {}
            for code, item in pairs(registrations.codes) do
                result[#result + 1] = {code = code, id = item.id, nickname = item.nickname, used = item.used, revoked = item.revoked}
            end
            table.sort(result, function(a, b) return tostring(a.id) < tostring(b.id) end)
            return {ok = true, codes = result}
        end
        if request.action == "ADMIN_REVOKE_CODE" then
            local code = type(request.code) == "string" and request.code:upper() or ""
            local item = registrations.codes[code]
            if not item then return {ok = false, error = "CODE NOT FOUND"} end
            if item.used then return {ok = false, error = "CODE ALREADY USED"} end
            if item.revoked then return {ok = false, error = "CODE ALREADY REVOKED"} end
            item.revoked = true
            item.revokedAt = os.epoch("utc")
            save(REGISTRATIONS, registrations)
            return {ok = true}
        end
        return {ok = false, error = "UNKNOWN ADMIN ACTION"}
    end
    return {ok = false, error = "UNKNOWN ACTION"}
end
local opened = false
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        rednet.open(name)
        opened = true
    end
end
if not opened then
    print("ERROR: NO MODEM FOUND")
    return
end
print("================================")
print("          BANK SERVER")
print("================================")
print("Computer ID: " .. os.getComputerID())
local accountCount = 0
for _ in pairs(accounts.accounts) do accountCount = accountCount + 1 end
print("Accounts: " .. accountCount)
print("Starting capital: " .. settings.startingBalance .. " BC")
print("Network: READY")
print("--------------------------------")
print("Waiting for requests...")
print("")

while true do
    local sender, request = rednet.receive(PROTOCOL)
    accounts = load(ACCOUNTS, {nextId = 1, accounts = {}})
    history = load(HISTORY, {})
    settings = load(SETTINGS, {startingBalance = 500, currency = "BC", bankName = "Bank"})
    registrations = load(REGISTRATIONS, {codes = {}})
    local ok, response = pcall(handle, sender, request)
    if not ok then
        print("ERROR: " .. tostring(response))
        response = {ok = false, error = "SERVER ERROR"}
    end
    reply(sender, response)
    if type(request) == "table" then
        print("Request: " .. tostring(request.action))
        print("From computer: " .. sender)
    end
end
