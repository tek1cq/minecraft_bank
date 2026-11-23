local SERVER_ID = 203
local PROTOCOL = "bank"
local TIMEOUT = 8

local accountId
local accountPin
local accountName
local accountCreated
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
    register = "REGISTER",
    account = "YOUR ACCOUNT",
    myAccount = "ACCOUNT PROFILE",
    profile = "ACCOUNT PROFILE",
    registered = "REGISTRATION DATE",
    notAvailable = "NOT AVAILABLE",
    history = "TRANSACTION HISTORY",
    notifications = "INCOMING PAYMENTS",
    noNotifications = "NO INCOMING PAYMENTS",
    noHistory = "NO TRANSACTIONS FOUND",
    accountOpened = "ACCOUNT OPENED",
    sentTo = "SENT TO",
    receivedFrom = "RECEIVED FROM",
    backPage = "BACK",
    previousPage = "PREV",
    nextPage = "NEXT",
    transfer = "SEND MONEY",
    refresh = "REFRESH BALANCE",
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
    registrationCode = "Enter your registration code",
    newPin = "Create a 6-digit PIN",
    repeatPin = "Confirm your PIN",
    invalidId = "Enter a valid Bank ID",
    invalidPin = "PIN must contain 6 digits",
    pinsDiffer = "The PINs do not match",
    created = "ACCOUNT READY",
    yourId = "YOUR NEW BANK ID",
    credited = "STARTING BALANCE",
    recipientId = "Recipient Bank ID or nickname",
    recipientPrompt = "Enter Bank ID or account nickname",
    amount = "Amount in BC",
    recipientName = "RECIPIENT",
    recipientBankId = "BANK ID",
    backToMenu = "BACK TO MENU",
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
    invalidCode = "Invalid, used or revoked registration code",
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
    ["INVALID REGISTRATION CODE"] = "invalidCode",
    ["ACCOUNT ALREADY EXISTS"] = "invalidCode",
    ["PIN MUST BE 6 DIGITS"] = "invalidPin",
    ["NAME ALREADY REGISTERED"] = "nameTaken",
    ["RECIPIENT NOT FOUND OR BLOCKED"] = "recipientMissing",
    ["RECIPIENT NOT FOUND"] = "recipientMissing",
    ["RECIPIENT BLOCKED"] = "recipientMissing",
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

local function drawSmallButton(id, label, x, y, buttonWidth, key, style)
    local width, height = dimensions()
    if y < 1 or y > height then
        return
    end

    local background = style == "primary" and palette.gold or palette.surface
    local foreground = style == "primary" and colors.black or palette.text
    local text = clipped(label, buttonWidth - 2)
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
        local event, button, x, y = os.pullEvent("mouse_click")
        if button == 1 then
            for _, item in ipairs(buttons) do
                if x >= item.left and x <= item.right
                    and y >= item.top and y <= item.bottom then
                    return item.id
                end
            end
        end
    end
end

local function pause(value, isError)
    drawHeader(isError and tr("error") or tr("notice"))
    drawMessage(value or tr("continueText"), 9, isError and palette.danger or palette.text)
    local _, height = dimensions()
    drawButton("continue", tr("continueText"), height - 4, nil, "primary")
    drawFooter("TAP TO CONTINUE")
    waitChoice()
end

local function ask(title, prompt, hidden)
    drawHeader(title, tr("keyboard"))
    drawMessage(prompt, 9, palette.text)
    drawPanel(12, " ", palette.goldLight)
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
    accountCreated = response.created
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
    accountCreated = response.created
    balance = response.balance
    return true
end

local function register()
    local code = ask(tr("register"), tr("registrationCode"), false)
    code = code:upper():gsub("%s+", "")

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
        code = code,
        pin = pin
    })

    if not response.ok then
        showError(response)
        return false
    end

    accountId = response.id
    accountPin = pin
    accountName = response.name
    accountCreated = response.created
    balance = response.balance

    drawHeader(tr("created"), accountName)
    drawText(9, tr("yourId"), palette.muted)
    drawPanel(11, tostring(accountId), palette.goldLight)
    drawText(14, tr("credited"), palette.muted)
    drawText(15, tostring(balance) .. " BC", palette.success)

    local _, height = dimensions()
    drawButton("continue", tr("continueText"), height - 4, nil, "primary")
    drawFooter("SAVE YOUR BANK ID")
    waitChoice()

    return true
end

local function showProfile()
    if not updateBalance() then
        return
    end

    drawHeader(tr("profile"), accountName)
    drawText(8, "ACCOUNT HOLDER", palette.muted)
    drawPanel(9, accountName, palette.text)
    drawText(11, tr("accountId"), palette.muted)
    drawPanel(12, tostring(accountId), palette.goldLight)
    drawText(14, tr("registered"), palette.muted)

    if accountCreated then
        drawPanel(15, os.date("%d.%m.%Y", math.floor(accountCreated / 1000)), palette.text)
    else
        drawPanel(15, tr("notAvailable"), palette.muted)
    end

    drawText(17, tr("available"), palette.muted)
    drawText(18, tostring(balance) .. " BC", palette.success)

    local _, height = dimensions()
    drawButton("back", tr("back"), height - 4, nil, "primary")
    drawFooter("TAP TO RETURN")
    waitChoice()
end

local function transfer()
    drawHeader(tr("transfer"), accountName)
    drawText(8, tr("available"), palette.muted)
    drawPanel(10, tostring(balance) .. " BC", palette.goldLight)
    drawMessage(tr("recipientPrompt"), 13, palette.text)
    drawButton("continue", tr("continueText"), 16, nil, "primary")
    drawButton("back", tr("backToMenu"), 18, nil)
    drawFooter("SELECT AN OPTION")

    if waitChoice() == "back" then
        return
    end

    local recipientInput = ask(tr("transfer"), tr("recipientPrompt"), false)
    recipientInput = tostring(recipientInput or ""):match("^%s*(.-)%s*$")

    if recipientInput == "" then
        pause(tr("invalidRecipient"), true)
        return
    end

    local lookup = request({
        action = "LOOKUP_RECIPIENT",
        id = accountId,
        pin = accountPin,
        recipient = recipientInput
    })

    if not lookup.ok then
        showError(lookup)
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
    drawText(8, tr("recipientName"), palette.muted)
    drawPanel(9, lookup.name, palette.text)
    drawText(11, tr("recipientBankId"), palette.muted)
    drawPanel(12, tostring(lookup.id), palette.goldLight)
    drawText(14, "PAYMENT AMOUNT", palette.muted)
    drawPanel(15, tostring(amount) .. " BC", palette.success)
    drawButton("yes", tr("confirm"), 17, nil, "primary")
    drawButton("no", tr("backToMenu"), 18, nil)
    drawFooter("CONFIRM OR GO BACK")

    if waitChoice() ~= "yes" then
        return
    end

    local response = request({
        action = "TRANSFER",
        id = accountId,
        pin = accountPin,
        target = lookup.id,
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
        accountCreated = balanceResponse.created
    end

    drawHeader(tr("completed"))
    drawText(8, tr("sent"), palette.muted)
    drawPanel(10, tostring(amount) .. " BC", palette.success)
    drawText(12, tr("recipientName"), palette.muted)
    drawPanel(13, lookup.name, palette.text)
    drawText(15, tr("recipientBankId"), palette.muted)
    drawPanel(16, tostring(lookup.id), palette.goldLight)

    local _, height = dimensions()
    drawButton("back", tr("done"), height - 4, nil, "primary")
    drawFooter("PAYMENT CONFIRMED")
    waitChoice()
end
local function showHistory()
    local entries = {}
    local filter = "all"
    local page = 1

    local function loadHistory()
        local response = request({
            action = "HISTORY",
            id = accountId,
            pin = accountPin
        })

        if not response.ok then
            showError(response)
            return false
        end

        entries = response.transactions or {}
        return true
    end

    local function filteredEntries()
        local result = {}

        for _, entry in ipairs(entries) do
            local outgoing = tostring(entry.from) == tostring(accountId)
            local incoming = entry.action == "REGISTER" or not outgoing

            if filter == "all"
                or (filter == "incoming" and incoming)
                or (filter == "outgoing" and outgoing) then
                result[#result + 1] = entry
            end
        end

        return result
    end

    local function showDetails(entry)
        local outgoing = tostring(entry.from) == tostring(accountId)
        local registered = entry.action == "REGISTER"
        local dateText = os.date("%d.%m.%Y %H:%M", math.floor((entry.time or 0) / 1000))
        local kind
        local other
        local otherId
        local amount = tonumber(entry.amount) or 0
        local amountText
        local amountColor

        if registered then
            kind = "ACCOUNT OPENED"
            other = "Bank"
            otherId = "SYSTEM"
            amountText = "+" .. tostring(amount) .. " BC"
            amountColor = palette.success
        elseif outgoing then
            kind = "OUTGOING TRANSFER"
            other = tostring(entry.otherName or ("#" .. tostring(entry.to)))
            otherId = tostring(entry.to)
            amountText = "-" .. tostring(amount) .. " BC"
            amountColor = palette.danger
        else
            kind = "INCOMING TRANSFER"
            other = tostring(entry.otherName or ("#" .. tostring(entry.from)))
            otherId = tostring(entry.from)
            amountText = "+" .. tostring(amount) .. " BC"
            amountColor = palette.success
        end

        drawHeader("TRANSACTION DETAILS")
        drawText(8, dateText, palette.muted)
        drawText(9, "TYPE", palette.muted)
        drawText(10, kind, palette.text)
        drawText(12, registered and "SOURCE" or (outgoing and "RECIPIENT" or "SENDER"), palette.muted)
        drawText(13, other, palette.text)
        drawText(14, "#" .. otherId, palette.muted)
        drawText(15, amountText, amountColor)

        local _, height = dimensions()
        drawButton("back", tr("backPage"), height - 3, nil, "primary")
        drawFooter("TAP TO RETURN")
        waitChoice()
    end

    if not loadHistory() then
        return
    end

    while true do
        local visible = filteredEntries()
        local pageSize = 2
        local pageCount = math.max(1, math.ceil(#visible / pageSize))
        page = math.min(page, pageCount)

        drawHeader(tr("history"), accountName)
        local width = dimensions()
        local buttonWidth = math.floor(width / 3)
        drawSmallButton("all", "ALL", 1, 7, buttonWidth, nil, filter == "all" and "primary" or nil)
        drawSmallButton("incoming", "IN", buttonWidth + 1, 7, buttonWidth, nil, filter == "incoming" and "primary" or nil)
        drawSmallButton("outgoing", "OUT", buttonWidth * 2 + 1, 7, width - buttonWidth * 2, nil, filter == "outgoing" and "primary" or nil)

        if #visible == 0 then
            drawMessage(tr("noHistory"), 11, palette.muted)
        else
            for slot = 1, pageSize do
                local index = (page - 1) * pageSize + slot
                local entry = visible[index]
                local y = 9 + (slot - 1) * 4

                if entry then
                    local dateText = os.date("%d.%m.%Y %H:%M", math.floor((entry.time or 0) / 1000))
                    local outgoing = tostring(entry.from) == tostring(accountId)
                    local registered = entry.action == "REGISTER"
                    local other
                    local amountText
                    local foreground

                    if registered then
                        other = "Bank"
                        amountText = "+" .. tostring(entry.amount or 0) .. " BC"
                        foreground = palette.success
                    elseif outgoing then
                        other = "TO " .. tostring(entry.otherName or ("#" .. tostring(entry.to)))
                        amountText = "-" .. tostring(entry.amount or 0) .. " BC"
                        foreground = palette.danger
                    else
                        other = "FROM " .. tostring(entry.otherName or ("#" .. tostring(entry.from)))
                        amountText = "+" .. tostring(entry.amount or 0) .. " BC"
                        foreground = palette.success
                    end

                    drawText(y, dateText, palette.muted)
                    drawText(y + 1, other, palette.text)
                    drawText(y + 2, amountText, foreground)

                    buttons[#buttons + 1] = {
                        id = "detail" .. tostring(slot),
                        left = 1,
                        right = width,
                        top = y,
                        bottom = y + 2
                    }
                end
            end
        end

        local _, height = dimensions()
        local navWidth = math.floor((width - 2) / 3)
        local buttonY = height - 4
        drawSmallButton("back", tr("backPage"), 1, buttonY, navWidth, nil, "primary")
        drawSmallButton("previous", tr("previousPage"), navWidth + 2, buttonY, navWidth, nil)
        drawSmallButton("next", tr("nextPage"), navWidth * 2 + 3, buttonY, width - (navWidth * 2 + 2), nil)
        drawFooter(tostring(page) .. " / " .. tostring(pageCount) .. "  |  TAP TO NAVIGATE")

        local choice = waitChoice()
        if choice == "back" then
            return
        elseif choice == "previous" and page > 1 then
            page = page - 1
        elseif choice == "next" and page < pageCount then
            page = page + 1
        elseif choice == "all" then
            filter = "all"
            page = 1
        elseif choice == "incoming" then
            filter = "incoming"
            page = 1
        elseif choice == "outgoing" then
            filter = "outgoing"
            page = 1
        elseif choice == "detail1" or choice == "detail2" then
            local slot = choice == "detail1" and 1 or 2
            local entry = visible[(page - 1) * pageSize + slot]
            if entry then
                showDetails(entry)
            end
        end
    end
end


local function showNotifications()
    local entries = {}
    local page = 1

    local response = request({
        action = "NOTIFICATIONS",
        id = accountId,
        pin = accountPin
    })

    if not response.ok then
        showError(response)
        return
    end

    entries = response.transactions or {}

    while true do
        local width, height = dimensions()
        local pageSize = 2
        local pageCount = math.max(1, math.ceil(#entries / pageSize))
        page = math.min(page, pageCount)

        drawHeader(tr("notifications"), accountName)

        if #entries == 0 then
            drawMessage(tr("noNotifications"), 11, palette.muted)
        else
            for slot = 1, pageSize do
                local entry = entries[(page - 1) * pageSize + slot]
                local y = 9 + (slot - 1) * 4

                if entry then
                    local dateText = os.date("%d.%m.%Y %H:%M", math.floor((entry.time or 0) / 1000))
                    local senderName = tostring(entry.otherName or ("#" .. tostring(entry.from)))
                    drawText(y, dateText, palette.muted)
                    drawText(y + 1, "FROM " .. senderName, palette.text)
                    drawText(y + 2, "+" .. tostring(entry.amount or 0) .. " BC", palette.success)
                end
            end
        end

        local navWidth = math.floor((width - 2) / 3)
        local buttonY = height - 4
        drawSmallButton("back", tr("backPage"), 1, buttonY, navWidth, nil, "primary")
        drawSmallButton("previous", tr("previousPage"), navWidth + 2, buttonY, navWidth, nil)
        drawSmallButton("next", tr("nextPage"), navWidth * 2 + 3, buttonY, width - (navWidth * 2 + 2), nil)
        drawFooter(tostring(page) .. " / " .. tostring(pageCount) .. "  |  TAP TO NAVIGATE")

        local choice = waitChoice()
        if choice == "back" then
            return
        elseif choice == "previous" and page > 1 then
            page = page - 1
        elseif choice == "next" and page < pageCount then
            page = page + 1
        end
    end
end

local function accountMenu()
    while accountId do
        drawHeader("ACCOUNT OVERVIEW", accountName)
        drawText(8, tr("available"), palette.muted)
        drawPanel(10, tostring(balance) .. " BC", palette.goldLight)
        drawButton("refresh", tr("refresh"), 13, nil)
        drawLine(15, "-", palette.surface)

        local width, height = dimensions()
        local tabWidth = math.floor(width / 4)
        local tabY = height - 2
        drawSmallButton("profile", "PROF", 1, tabY, tabWidth, nil, "primary")
        drawSmallButton("transfer", "SEND", tabWidth + 1, tabY, tabWidth, nil)
        drawSmallButton("history", "HIST", tabWidth * 2 + 1, tabY, tabWidth, nil)
        drawSmallButton("notifications", "MAIL", tabWidth * 3 + 1, tabY, width - tabWidth * 3, nil)

        local choice = waitChoice()

        if choice == "profile" then
            showProfile()
        elseif choice == "transfer" then
            transfer()
        elseif choice == "history" then
            showHistory()
        elseif choice == "notifications" then
            showNotifications()
        elseif choice == "refresh" then
            if updateBalance() then
                pause(tr("balanceUpdated"))
            end
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

    drawButton("login", tr("login"), 12, nil, "primary")
    drawButton("register", tr("register"), 16, nil)
    drawFooter("SELECT AN OPTION")

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
