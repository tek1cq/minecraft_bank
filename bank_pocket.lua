
-- BANK POCKET CLIENT
-- Advanced Pocket Computer
-- Central bank server: 203

local SERVER_ID = 203
local PROTOCOL = "bank"
local TIMEOUT = 8

local accountId = nil
local accountPin = nil
local accountName = nil
local balance = 0

local function clear()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function header()
    clear()
    term.setTextColor(colors.cyan)
    print("==========================")
    print("          BANK")
    print("==========================")
    term.setTextColor(colors.white)
    print("")
end

local function pause()
    print("")
    print("Press Enter...")
    read()
end

local function inputNumber(prompt)
    write(prompt)
    local value = tonumber(read())
    return value
end

local function request(data)
    rednet.send(SERVER_ID, data, PROTOCOL)

    local deadline = os.clock() + TIMEOUT

    while true do
        local remaining = deadline - os.clock()

        if remaining <= 0 then
            return {
                ok = false,
                error = "SERVER TIMEOUT"
            }
        end

        local sender, response =
            rednet.receive(PROTOCOL, remaining)

        if sender == SERVER_ID then
            if type(response) == "table" then
                return response
            end

            return {
                ok = false,
                error = "INVALID SERVER RESPONSE"
            }
        end

        if sender == nil then
            return {
                ok = false,
                error = "SERVER TIMEOUT"
            }
        end
    end
end

local function showError(response)
    term.setTextColor(colors.red)
    print("ERROR: " .. tostring(response.error))
    term.setTextColor(colors.white)
end

local function updateBalance()
    local response = request({
        action = "BALANCE",
        id = accountId,
        pin = accountPin
    })

    if not response.ok then
        showError(response)
        return false
    end

    balance = response.balance
    accountName = response.name

    return true
end

local function login()
    header()

    print("ACCOUNT LOGIN")
    print("")

    local id = inputNumber("Bank ID: ")

    if not id or id < 1 or id % 1 ~= 0 then
        print("Invalid ID.")
        pause()
        return false
    end

    write("PIN: ")
    local pin = read("*")

    local response = request({
        action = "BALANCE",
        id = id,
        pin = pin
    })

    if not response.ok then
        showError(response)
        pause()
        return false
    end

    accountId = id
    accountPin = pin
    accountName = response.name
    balance = response.balance

    return true
end

local function register()
    header()

    print("NEW ACCOUNT")
    print("")
    print("Enter your Minecraft nickname.")
    write("Nickname: ")
    local name = read()

    print("")
    print("Create a 6-digit PIN.")
    write("PIN: ")
    local pin = read("*")

    if not pin:match("^%d%d%d%d%d%d$") then
        print("PIN must contain 6 digits.")
        pause()
        return false
    end

    write("Repeat PIN: ")
    local repeatPin = read("*")

    if pin ~= repeatPin then
        print("PINs do not match.")
        pause()
        return false
    end

    local response = request({
        action = "REGISTER",
        name = name,
        pin = pin
    })

    if not response.ok then
        showError(response)
        pause()
        return false
    end

    accountId = response.id
    accountPin = pin
    accountName = name
    balance = response.balance

    header()

    term.setTextColor(colors.lime)
    print("ACCOUNT CREATED!")
    term.setTextColor(colors.white)
    print("")
    print("Your bank ID: " .. tostring(accountId))
    print("Starting balance: " .. tostring(balance) .. " BC")
    print("")
    print("Remember your ID and PIN!")

    pause()
    return true
end

local function showBalance()
    header()

    if updateBalance() then
        term.setTextColor(colors.lime)
        print("YOUR BALANCE")
        print("")
        term.setTextColor(colors.white)
        print(tostring(balance) .. " BC")
        print("")
        print("Account: " .. tostring(accountId))
        print("Name: " .. tostring(accountName))
    end

    pause()
end

local function transfer()
    header()

    print("MONEY TRANSFER")
    print("")

    print("Your balance: " .. tostring(balance) .. " BC")
    print("")

    local target = inputNumber("Recipient bank ID: ")

    if not target or target < 1 or target % 1 ~= 0 then
        print("Invalid recipient ID.")
        pause()
        return
    end

    local amount = inputNumber("Amount (BC): ")

    if not amount or amount < 1 or amount % 1 ~= 0 then
        print("Invalid amount.")
        pause()
        return
    end

    print("")
    print("Sending transfer...")

    local response = request({
        action = "TRANSFER",
        id = accountId,
        pin = accountPin,
        target = target,
        amount = amount
    })

    if response.ok then
        term.setTextColor(colors.lime)
        print("")
        print("TRANSFER COMPLETE!")
        term.setTextColor(colors.white)

        updateBalance()
    else
        showError(response)
    end

    pause()
end

local function accountMenu()
    while true do
        header()

        print("Welcome, " .. tostring(accountName))
        print("ID: " .. tostring(accountId))
        print("Balance: " .. tostring(balance) .. " BC")
        print("")
        print("1. View balance")
        print("2. Transfer money")
        print("3. Refresh balance")
        print("0. Log out")
        print("")

        write("Select: ")
        local choice = read()

        if choice == "1" then
            showBalance()

        elseif choice == "2" then
            transfer()

        elseif choice == "3" then
            header()

            if updateBalance() then
                print("Balance updated.")
                print(tostring(balance) .. " BC")
            else
                print("Could not update balance.")
            end

            pause()

        elseif choice == "0" then
            accountId = nil
            accountPin = nil
            accountName = nil
            balance = 0
            return
        end
    end
end

-- INITIALIZATION

clear()

local modemFound = false

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        rednet.open(name)
        modemFound = true
    end
end

if not modemFound then
    print("ERROR: MODEM NOT FOUND")
    return
end

while true do
    header()

    print("1. Login")
    print("2. Create account")
    print("0. Exit")
    print("")

    write("Select: ")
    local choice = read()

    if choice == "1" then
        if login() then
            accountMenu()
        end

    elseif choice == "2" then
        if register() then
            accountMenu()
        end

    elseif choice == "0" then
        clear()
        print("Thank you for using Bank.")
        break
    end
end
