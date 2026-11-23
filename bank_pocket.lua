local SERVER_ID = 203
local PROTOCOL = "bank"
local TIMEOUT = 8

local W, H = term.getSize()
local buttons = {}

local accountId
local accountPin
local accountName
local balance = 0

local messages = {
        bank = "BANK",
        welcome = "WELCOME",
        subtitle = "ELECTRONIC BANK",
        login = "LOG IN",
        register = "OPEN ACCOUNT",
        cabinet = "ACCOUNT",
        myAccount = "MY ACCOUNT",
        transfer = "TRANSFER",
        refresh = "REFRESH BALANCE",
        logout = "LOG OUT",
        balance = "BALANCE",
        available = "AVAILABLE BALANCE",
        accountNumber = "ACCOUNT #",
        input = "INPUT",
        keyboard = "USE KEYBOARD",
        continueText = "CONTINUE",
        back = "BACK",
        notice = "NOTICE",
        error = "ERROR",
        bankId = "Bank ID:",
        pin = "Enter PIN:",
        nickname = "Minecraft nickname:",
        newPin = "Create a 6-digit PIN:",
        repeatPin = "Repeat PIN:",
        invalidId = "Invalid ID",
        invalidPin = "PIN must contain 6 digits",
        pinsDiffer = "PINs do not match",
        created = "ACCOUNT CREATED",
        yourId = "YOUR BANK ID",
        credited = "Credited: ",
        recipientId = "Recipient ID:",
        amount = "Transfer amount:",
        invalidRecipient = "Invalid recipient ID",
        invalidAmount = "Invalid amount",
        notEnough = "Not enough funds",
        confirmation = "CONFIRMATION",
        confirmTransfer = "Confirm this transfer?",
        confirm = "CONFIRM",
        cancel = "CANCEL",
        cancelled = "Transfer cancelled",
        completed = "TRANSFER COMPLETE",
        sent = "Successfully sent",
        recipient = "Recipient: ",
        done = "DONE",
        balanceUpdated = "Balance updated",
        noModem = "No modem found",
        connectionError = "CONNECTION ERROR",
        noServer = "No response from server",
        badResponse = "Invalid server response",
        unknownError = "Unknown error",
        secure = "BANK  |  SECURE SYSTEM",
        yes = "YES",
        no = "NO"
}

local serverErrors = {
    ["INVALID ID OR PIN"] = "invalidLogin",
    ["ACCOUNT BLOCKED"] = "blocked",
    ["INVALID NAME"] = "invalidName",
    ["PIN MUST BE 6 DIGITS"] = "invalidPin",
    ["NAME ALREADY REGISTERED"] = "nameTaken",
    ["RECIPIENT NOT FOUND OR BLOCKED"] = "recipientMissing",
    ["INVALID AMOUNT"] = "invalidAmount",
    ["CANNOT TRANSFER TO YOURSELF"] = "selfTransfer",
    ["NOT ENOUGH MONEY"] = "notEnough",
    ["UNKNOWN ACTION"] = "unknownAction",
    ["SERVER ERROR"] = "serverError"
}

messages.invalidLogin = "Wrong ID or PIN"
messages.blocked = "Account is blocked"
messages.invalidName = "Invalid nickname"
messages.nameTaken = "Nickname is already registered"
messages.recipientMissing = "Recipient not found or blocked"
messages.selfTransfer = "You cannot transfer money to yourself"
messages.unknownAction = "Unknown action"
messages.serverError = "Server error"

local function tr(key)
    return messages[key] or key
end

local function utf8Chars(value)
    local result = {}
    for char in tostring(value):gmatch("[\0-\127\194-\244][\128-\191]*") do
        result[#result + 1] = char
    end
    return result
end

local function textWidth(value)
    return #utf8Chars(value)
end

local function cutText(value, limit)
    local chars = utf8Chars(value)
    local result = {}
    for i = 1, math.min(#chars, limit) do
        result[#result + 1] = chars[i]
    end
    return table.concat(result)
end

local function color(bg, fg)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
end

local function clear()
    color(colors.black, colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    buttons = {}
end

local function center(y, value, fg)
    local screenW, screenH = term.getSize()
    if y < 1 or y > screenH then
        return
    end

    local valueText = cutText(tostring(value), screenW)
    local x = math.floor((screenW - #valueText) / 2) + 1

    term.setBackgroundColor(colors.black)
    term.setTextColor(fg or colors.white)
    term.setCursorPos(x, y)
    term.write(valueText)
end

local function separator(y)
    -- Use plain ASCII because the pocket terminal font may not support box-drawing glyphs.
    local screenW, screenH = term.getSize()
    if y < 1 or y > screenH then
        return
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.orange)
    term.setCursorPos(2, y)
    write(string.rep("-", math.max(1, screenW - 2)))
    color(colors.black, colors.white)
end

local function header(title, subtitle)
    clear()
    center(1, tr("bank"), colors.orange)
    separator(2)
    center(3, title, colors.orange)

    if subtitle then
        center(4, subtitle, colors.gray)
    end

    separator(5)
end

local function addButton(id, label, y, key)
    local screenW, screenH = term.getSize()
    if y < 1 or y > screenH then
        return
    end

    local width = math.min(screenW - 2, math.max(10, textWidth(label) + 6))
    local safeLabel = cutText(label, math.max(1, width - 4))
    local x = math.max(1, math.floor((screenW - width) / 2) + 1)
    local buttonText = "[ " .. safeLabel .. " ]"
    local textX = x + math.floor((width - textWidth(buttonText)) / 2)

    -- Gold button with black text. The whole bar is clickable.
    color(colors.orange, colors.black)
    term.setCursorPos(x, y)
    write(string.rep(" ", width))
    term.setCursorPos(textX, y)
    write(buttonText)

    buttons[#buttons + 1] = {
        id = id,
        key = key,
        x1 = x,
        x2 = x + width - 1,
        y1 = y,
        y2 = y
    }

    color(colors.black, colors.white)
end

local function waitChoice()
    while true do
        local event, a, b, c = os.pullEvent()

        if event == "char" then
            for _, button in ipairs(buttons) do
                if button.key == a then
                    return button.id
                end
            end
        elseif event == "mouse_click" then
            local mouseButton, x, y = a, b, c
            if mouseButton == 1 then
                for _, button in ipairs(buttons) do
                    if y >= button.y1 and y <= button.y2
                        and x >= button.x1 and x <= button.x2 then
                        return button.id
                    end
                end
            end
        end
    end
end

local function pause(message)
    header(tr("notice"))
    center(8, message or tr("continueText"))
    addButton("back", tr("continueText"), 12, "1")
    waitChoice()
end

local function inputScreen(title, prompt, hidden)
    header(title)
    center(8, prompt)
    center(10, tr("keyboard"), colors.gray)
    term.setCursorPos(3, 12)
    term.setTextColor(colors.lightGray)

    if hidden then
        return read("*")
    end

    return read()
end

local function inputNumber(prompt)
    return tonumber(inputScreen(tr("input"), prompt))
end

local function request(data)
    rednet.send(SERVER_ID, data, PROTOCOL)

    local deadline = os.clock() + TIMEOUT

    while true do
        local remaining = deadline - os.clock()
        if remaining <= 0 then
            return {ok = false, error = tr("noServer")}
        end

        local sender, response = rednet.receive(PROTOCOL, remaining)

        if sender == SERVER_ID then
            if type(response) == "table" then
                return response
            end
            return {ok = false, error = tr("badResponse")}
        elseif sender == nil then
            return {ok = false, error = tr("noServer")}
        end
    end
end

local function showError(response)
    local message = tostring(response.error or tr("unknownError"))
    local key = serverErrors[message]

    if key then
        message = tr(key)
    end

    header(tr("error"))
    center(8, message, colors.red)
    addButton("back", tr("back"), 12, "1")
    waitChoice()
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
    local id = inputNumber(tr("bankId"))

    if not id or id < 1 or id % 1 ~= 0 then
        pause(tr("invalidId"))
        return false
    end

    local pin = inputScreen(tr("login"), tr("pin"), true)
    local response = request({
        action = "BALANCE",
        id = id,
        pin = pin
    })

    if not response.ok then
        showError(response)
        return false
    end

    accountId = id
    accountPin = pin
    accountName = response.name
    balance = response.balance
    return true
end

local function register()
    local name = inputScreen(tr("register"), tr("nickname"))
    local pin = inputScreen(tr("register"), tr("newPin"), true)

    if not pin:match("^%d%d%d%d%d%d$") then
        pause(tr("invalidPin"))
        return false
    end

    local repeatedPin = inputScreen(tr("register"), tr("repeatPin"), true)
    if pin ~= repeatedPin then
        pause(tr("pinsDiffer"))
        return false
    end

    local response = request({
        action = "REGISTER",
        name = name,
        pin = pin
    })

    if not response.ok then
        showError(response)
        return false
    end

    accountId = response.id
    accountPin = pin
    accountName = name
    balance = response.balance

    header(tr("created"))
    center(8, tr("yourId"), colors.gray)
    center(10, accountId, colors.lightGray)
    center(12, tr("credited") .. balance .. " BC", colors.lime)
    addButton("continue", tr("continueText"), 16, "1")
    waitChoice()

    return true
end

local function showBalance()
    header(tr("myAccount"), accountName)

    if updateBalance() then
        center(8, tr("available"), colors.gray)
        center(10, tostring(balance) .. " BC", colors.lightGray)
        center(13, tr("accountNumber") .. tostring(accountId))
    end

    addButton("back", tr("back"), H - 2, "1")
    waitChoice()
end

local function transfer()
    header(tr("transfer"))
    center(8, tr("available") .. ": " .. balance .. " BC", colors.lightGray)

    local target = inputNumber(tr("recipientId"))
    if not target or target < 1 or target % 1 ~= 0 then
        pause(tr("invalidRecipient"))
        return
    end

    local amount = inputNumber(tr("amount"))
    if not amount or amount < 1 or amount % 1 ~= 0 then
        pause(tr("invalidAmount"))
        return
    end

    if amount > balance then
        pause(tr("notEnough"))
        return
    end

    header(tr("confirmation"))
    center(8, tr("recipient") .. target)
    center(10, tr("amount") .. " " .. amount .. " BC", colors.lightGray)
    center(12, tr("confirmTransfer"))

    addButton("yes", tr("confirm"), 15, "1")
    addButton("no", tr("cancel"), 17, "2")

    if waitChoice() ~= "yes" then
        pause(tr("cancelled"))
        return
    end

    local response = request({
        action = "TRANSFER",
        id = accountId,
        pin = accountPin,
        target = target,
        amount = amount
    })

    if not response.ok then
        showError(response)
        return
    end

    updateBalance()
    header(tr("completed"))
    center(9, tr("sent"), colors.lime)
    center(11, amount .. " BC", colors.lightGray)
    center(13, tr("recipient") .. target)
    addButton("back", tr("done"), 17, "1")
    waitChoice()
end

local function accountMenu()
    while accountId do
        header(tr("cabinet"), accountName)
        center(7, tr("balance"), colors.gray)
        center(8, tostring(balance) .. " BC", colors.lightGray)

        addButton("balance", tr("myAccount"), 10, "1")
        addButton("transfer", tr("transfer"), 12, "2")
        addButton("refresh", tr("refresh"), 14, "3")
        addButton("logout", tr("logout"), 18, "0")
        center(19, "CLICK OR PRESS A NUMBER", colors.gray)

        local choice = waitChoice()

        if choice == "balance" then
            showBalance()
        elseif choice == "transfer" then
            transfer()
        elseif choice == "refresh" then
            if updateBalance() then
                pause(tr("balanceUpdated"))
            end
        elseif choice == "logout" then
            accountId = nil
            accountPin = nil
            accountName = nil
            balance = 0
        end
    end
end

local modemFound = false
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        rednet.open(name)
        modemFound = true
    end
end

if not modemFound then
    header(tr("connectionError"))
    center(9, tr("noModem"), colors.red)
    return
end

while true do
    header(tr("welcome"))
    center(8, tr("subtitle"), colors.gray)

    addButton("login", tr("login"), 11, "1")
    addButton("register", tr("register"), 13, "2")

    center(H, "CLICK A BUTTON OR PRESS ITS NUMBER", colors.gray)

    local choice = waitChoice()

    if choice == "login" then
        if login() then
            accountMenu()
        end
    elseif choice == "register" then
        if register() then
            accountMenu()
        end
    end
end
