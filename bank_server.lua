local DATA = "bank_data"
local ACCOUNTS = DATA .. "/accounts.db"
local HISTORY = DATA .. "/transactions.db"
local SETTINGS = DATA .. "/settings.db"
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

local function handle(sender, request)
    if type(request) ~= "table" then
        return {ok = false, error = "INVALID REQUEST"}
    end
    if request.action == "REGISTER" then
        local name = request.name
        local pin = request.pin
        if type(name) ~= "string" or #name < 3 or #name > 20 then
            return {ok = false, error = "INVALID NAME"}
        end
        if type(pin) ~= "string" or not pin:match("^%d%d%d%d%d%d$") then
            return {ok = false, error = "PIN MUST BE 6 DIGITS"}
        end
        for _, account in pairs(accounts.accounts) do
            if account.name:lower() == name:lower() then
                return {ok = false, error = "NAME ALREADY REGISTERED"}
            end
        end
        local id = accounts.nextId
        accounts.nextId = id + 1
        accounts.accounts[tostring(id)] = {
            id = id,
            name = name,
            pin = pin,
            balance = settings.startingBalance,
            blocked = false,
            created = os.epoch("utc")
        }
        save(ACCOUNTS, accounts)
        log("REGISTER", nil, id, settings.startingBalance)
        return {
            ok = true,
            message = "ACCOUNT CREATED",
            id = id,
            balance = settings.startingBalance
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
            balance = account.balance
        }
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
                result[#result + 1] = entry
                if #result >= 40 then
                    break
                end
            end
        end
        return {ok = true, transactions = result}
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
print("Accounts: " .. #({}))
print("Starting capital: " .. settings.startingBalance .. " BC")
print("Network: READY")
print("--------------------------------")
print("Waiting for requests...")
print("")

while true do
    local sender, request = rednet.receive(PROTOCOL)
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
