local SERVER_ID = 203
local PROTOCOL = "bank"
local TIMEOUT = 8

local accountId
local accountPin
local accountName
local balance = 0
local buttons = {}

local palette = {
    background = colors.black,
    surface = colors.gray,
    surfaceDark = colors.lightGray,
    gold = colors.orange,
    goldLight = colors.yellow,
    text = colors.white,
    muted = colors.lightGray,
    success = colors.lime,
    danger = colors.red
}

local messages = {
    bank = "BANK",
    welcome = "WELCOME",
    subtitle = "PRIVATE DIGITAL BANKING",
    login = "SIGN IN",
    register = "OPEN ACCOUNT",
    account = "YOUR ACCOUNT",
    myAccount = "ACCOUNT DETAILS",
    transfer = "SEND MONEY",
    refresh = "REFRESH BALANCE",
    logout = "SIGN OUT",
    available = "AVAILABLE BALANCE",
    accountId = "ACCOUNT ID",
    input = "SECURE INPUT",
    keyboard = "TYPE USING KEYBOARD",
    back = "BACK",
    continueText = "CONTINUE",
    notice = "NOTICE",
    error = "SOMETHING WENT WRONG",
    bankId = "Enter your Bank ID",
    pin = "Enter your 6-digit PIN",
    nickname = "Choose a Minecraft nickname",
    newPin = "Create a 6-digit PIN",
    repeatPin = "Confirm your PIN",
    invalidId = "Enter a valid Bank ID",
    invalidPin = "PIN must contain 6 digits",
    pinsDiffer = "The PINs do not match",
    created = "ACCOUNT READY",
    yourId = "YOUR NEW BANK ID",
    credited = "STARTING BALANCE",
    recipientId = "Recipient Bank ID",
    amount = "Amount in BC",
    invalidRecipient = "Enter a valid recipient ID",
    invalidAmount = "Enter a positive whole amount",
    notEnough = "Your balance is too low",
    confirmation = "REVIEW TRANSFER",
    confirmTransfer = "Send this payment?",
    confirm = "CONFIRM PAYMENT",
    cancel = "CANCEL",
    cancelled = "Payment cancelled",
    completed = "PAYMENT SENT",
    sent = "TRANSFERRED",
    recipient = "TO ACCOUNT",
    done = "DONE",
    balanceUpdated = "Your balance is up to date",
    noModem = "No modem is available",
    connectionError = "CONNECTION ERROR",
    noServer = "The bank server did not respond",
    badResponse = "The server sent an invalid response",
    unknownError = "An unexpected error occurred",
    accountNotFound = "No account with this ID",
    invalidLogin = "Incorrect PIN",
    blocked = "This account is blocked",
    invalidName = "Nickname must be 3-20 characters",
    nameTaken = "This nickname is already registered",
    recipientMissing = "Recipient not found or unavailable",
    selfTransfer = "You cannot pay your own account",
    unknownAction = "The server does not support this request",
    serverError = "The server encountered an error"
}

local serverErrors = {
    ["INVALID ID OR PIN"] = "invalidLogin",
    ["ACCOUNT NOT FOUND"] = "accountNotFound",
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

local function tr(key)
    return messages[key] or tostring(key)
end

local function dimensions()
    return term.getSize()
end

local function setStyle(background, foreground)
    term.setBackgroundColor(background or palette.background)
    term.setTextColor(foreground or palette.text)
end

local function clearScreen()
    setStyle(palette.background, palette.text)
    term.clear()
    term.setCursorPos(1, 1)
    term.setCursorBlink(false)
    buttons = {}
end

local function clipped(value, limit)
    value = tostring(value or "")
    if #value <= limit then
        return value
    end
    if limit <= 3 then
        return value:sub(1, limit)
    end
    return value:sub(1, limit - 3) .. "..."
end

local function drawText(y, value, foreground, background)
    local width, height = dimensions()
    if y < 1 or y > height then
        return
    end

    value = clipped(value, width)
    local x = math.floor((width - #value) / 2) + 1

    setStyle(background or palette.background, foreground or palette.text)
    term.setCursorPos(1, y)
    term.clearLine()
    term.setCursorPos(x, y)
    term.write(value)
end

local function drawLine(y, character, foreground)
    local width, height = dimensions()
    if y < 1 or y > height then
        return
    end

    setStyle(palette.background, foreground or palette.gold)
    term.setCursorPos(1, y)
    term.write(string.rep(character or "-", width))
end

local function drawPanel(y, value, foreground)
    local width, height = dimensions()
    if y < 1 or y > height then
        return
    end

    local text = clipped(value, math.max(1, width - 4))
    local x = math.floor((width - #text) / 2) + 1

    setStyle(palette.surface, foreground or palette.text)
    term.setCursorPos(2, y)
    term.write(string.rep(" ", math.max(0, width - 2)))
    term.setCursorPos(x, y)
    term.write(text)
    setStyle(palette.background, palette.text)
end

local function drawButton(id, label, y, key, style)
    local width, height = dimensions()
    if y < 1 or y > height then
        return
    end

    local buttonWidth = math.min(width - 2, math.max(14, #label + 4))
    local x = math.floor((width - buttonWidth) / 2) + 1
    local background = style == "primary" and palette.gold or palette.surface
    local foreground = style == "primary" and colors.black or palette.text
    local text = clipped(label, buttonWidth - 4)
    local textX = x + math.floor((buttonWidth - #text) / 2)

    setStyle(background, foreground)
    term.setCursorPos(x, y)
    term.write(string.rep(" ", buttonWidth))
    term.setCursorPos(textX, y)
    term.write(text)

    buttons[#buttons + 1] = {
        id = id,
        key = key,
        left = x,
        right = x + buttonWidth - 1,
        top = y,
        bottom = y
    }

    setStyle(palette.background, palette.text)
end

local function drawHeader(title, subtitle)
    clearScreen()
    drawText(1, "B A N K", palette.goldLight)
    drawLine(2, "=", palette.gold)
    drawText(4, title, palette.text)

    if subtitle then
        drawText(5, subtitle, palette.muted)
    end

    drawLine(6, "-", palette.surface)
end

local function drawFooter(value)
    local _, height = dimensions()
    drawLine(height - 1, "-", palette.surface)
    drawText(height, value, palette.muted)
end

local function wrapText(value, maxWidth)
    local lines = {}
    local line = ""

    for word in tostring(value):gmatch("%S+") do
        if line == "" then
            line = word
        elseif #line + #word + 1 <= maxWidth then
            line = line .. " " .. word
        else
            lines[#lines + 1] = line
            line = word
        end
    end

    if line ~= "" then
        lines[#lines + 1] = line
    end

    return lines
end

local function drawMessage(value, startY, foreground)
    local width = dimensions()
    local lines = wrapText(value, math.max(10, width - 4))

    for index, line in ipairs(lines) do
        drawText(startY + index - 1, line, foreground or palette.text)
    end
end

local function waitChoice()
    while true do
        local event, first, second, third = os.pullEvent()

        if event == "char" then
            for _, button in ipairs(buttons) do
                if button.key and button.key == first then
                    return button.id
                end
            end
        elseif event == "mouse_click" and first == 1 then
            local x, y = second, third
            for _, button in ipairs(buttons) do
                if x >= button.left and x <= button.right
                    and y >= button.top and y <= button.bottom then
                    return button.id
                end
            end
        end
    end
end

local function pause(value, isError)
    drawHeader(isError and tr("error") or tr("notice"))
    drawMessage(value or tr("continueText"), 9, isError and palette.danger or palette.text)
    local _, height = dimensions()
    drawButton("continue", tr("continueText"), height - 4, "1", "primary")
    drawFooter("TAP TO CONTINUE  |  PRESS 1")
    waitChoice()
end

local function ask(title, prompt, hidden)
    drawHeader(title, tr("keyboard"))
    drawMessage(prompt, 9, palette.text)
    drawPanel(12, "                                ", palette.goldLight)
    term.setBackgroundColor(palette.surface)
    term.setTextColor(palette.goldLight)
    term.setCursorPos(4, 12)
    term.setCursorBlink(true)

    local value
    if hidden then
        value = read("*")
    else
        value = read()
    end

    term.setCursorBlink(false)
    setStyle(palette.background, palette.text)
    return value
end

local function askNumber(prompt)
    local value = ask(tr("input"), prompt, false)
    return tonumber(value)
end

local function request(data)
    rednet.send(SERVER_ID, data, PROTOCOL)
    local deadline = os.clock() + TIMEOUT

    while true do
        local remaining = deadline - os.clock()
        if remaining <= 0 then
            return {ok = false, error = "NO SERVER"}
        end

        local sender, response = rednet.receive(PROTOCOL, remaining)
        if sender == SERVER_ID then
            if type(response) == "table" then
                return response
            end
            return {ok = false, error = "INVALID RESPONSE"}
        elseif sender == nil then
            return {ok = false, error = "NO SERVER"}
        end
    end
end

local function showError(response)
    local message = tostring(response.error or tr("unknownError"))
    local key = serverErrors[message]

    if key then
        message = tr(key)
    elseif message == "NO SERVER" then
        message = tr("noServer")
    elseif message == "INVALID RESPONSE" then
        message = tr("badResponse")
    end

    pause(message, true)
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
    local id = askNumber(tr("bankId"))

    if not id or id < 1 or id % 1 ~= 0 then
        pause(tr("invalidId"), true)
        return false
    end

    local check = request({
        action = "CHECK_ID",
        id = id
    })

    if not check.ok then
        showError(check)
        return false
    end

    local pin = ask(tr("login"), tr("pin"), true)
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
    local name = ask(tr("register"), tr("nickname"), false)
    name = name:match("^%s*(.-)%s*$")

    local pin = ask(tr("register"), tr("newPin"), true)
    if not pin:match("^%d%d%d%d%d%d$") then
        pause(tr("invalidPin"), true)
        return false
    end

    local repeatedPin = ask(tr("register"), tr("repeatPin"), true)
    if pin ~= repeatedPin then
        pause(tr("pinsDiffer"), true)
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

    drawHeader(tr("created"), accountName)
    drawText(9, tr("yourId"), palette.muted)
    drawPanel(11, tostring(accountId), palette.goldLight)
    drawText(14, tr("credited"), palette.muted)
    drawText(15, tostring(balance) .. " BC", palette.success)

    local _, height = dimensions()
    drawButton("continue", tr("continueText"), height - 4, "1", "primary")
    drawFooter("SAVE YOUR BANK ID")
    waitChoice()

    return true
end

local function showAccount()
    drawHeader(tr("myAccount"), accountName)

    if updateBalance() then
        drawText(8, tr("available"), palette.muted)
        drawText(10, tostring(balance) .. " BC", palette.goldLight)
        drawLine(12, "-", palette.surface)
        drawText(14, tr("accountId"), palette.muted)
        drawText(16, tostring(accountId), palette.text)
    end

    local _, height = dimensions()
    drawButton("back", tr("back"), height - 4, "1", "primary")
    drawFooter("PRESS 1 TO RETURN")
    waitChoice()
end

local function transfer()
    drawHeader(tr("transfer"), accountName)
    drawText(8, tr("available"), palette.muted)
    drawText(9, tostring(balance) .. " BC", palette.goldLight)

    local target = askNumber(tr("recipientId"))
    if not target or target < 1 or target % 1 ~= 0 then
        pause(tr("invalidRecipient"), true)
        return
    end

    local amount = askNumber(tr("amount"))
    if not amount or amount < 1 or amount % 1 ~= 0 then
        pause(tr("invalidAmount"), true)
        return
    end

    if amount > balance then
        pause(tr("notEnough"), true)
        return
    end

    drawHeader(tr("confirmation"))
    drawText(8, tr("recipient"), palette.muted)
    drawPanel(9, tostring(target), palette.text)
    drawText(11, "PAYMENT AMOUNT", palette.muted)
    drawText(13, tostring(amount) .. " BC", palette.goldLight)
    drawText(15, tr("confirmTransfer"), palette.text)

    drawButton("yes", tr("confirm"), 17, "1", "primary")
    drawButton("no", tr("cancel"), 19, "2")
    drawFooter("1 CONFIRM  |  2 CANCEL")

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

    local balanceResponse = request({
        action = "BALANCE",
        id = accountId,
        pin = accountPin
    })

    if balanceResponse.ok then
        balance = balanceResponse.balance
        accountName = balanceResponse.name
    end

    drawHeader(tr("completed"))
    drawText(9, tr("sent"), palette.muted)
    drawText(11, tostring(amount) .. " BC", palette.success)
    drawText(14, tr("recipient"), palette.muted)
    drawText(15, tostring(target), palette.text)

    local _, height = dimensions()
    drawButton("back", tr("done"), height - 4, "1", "primary")
    drawFooter("PAYMENT CONFIRMED")
    waitChoice()
end

local function accountMenu()
    while accountId do
        drawHeader(tr("account"), accountName)
        drawText(8, tr("available"), palette.muted)
        drawText(10, tostring(balance) .. " BC", palette.goldLight)
        drawLine(12, "-", palette.surface)

        drawButton("balance", tr("myAccount"), 13, "1", "primary")
        drawButton("transfer", tr("transfer"), 16, "2")
        drawButton("refresh", tr("refresh"), 18, "3")
        drawFooter("1 ACCOUNT  2 SEND  3 REFRESH")

        local choice = waitChoice()

        if choice == "balance" then
            showAccount()
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
    drawHeader(tr("connectionError"))
    drawMessage(tr("noModem"), 10, palette.danger)
    drawFooter("BANK CLIENT")
    return
end

while true do
    drawHeader(tr("welcome"), tr("subtitle"))
    drawText(8, "YOUR MONEY,", palette.muted)
    drawText(9, "UNDER CONTROL.", palette.goldLight)

    drawButton("login", tr("login"), 12, "1", "primary")
    drawButton("register", tr("register"), 16, "2")
    drawFooter("1 SIGN IN  |  2 OPEN ACCOUNT")

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
