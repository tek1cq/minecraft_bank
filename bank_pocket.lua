
-- BANK POCKET CLIENT
-- Luxury Edition
-- CC:Tweaked 1.21.1
-- Central server: 203

local SERVER_ID = 203
local PROTOCOL = "bank"
local TIMEOUT = 8

local accountId
local accountPin
local accountName
local balance = 0

local W, H = term.getSize()
local buttons = {}

local C = {
    bg = colors.black,
    panel = colors.gray,
    button = colors.lightGray,
    text = colors.white,
    muted = colors.gray,
    accent = colors.lightGray,
    success = colors.lime,
    error = colors.red
}

local function color(bg, fg)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
end

local function clear()
    color(C.bg, C.text)
    term.clear()
    term.setCursorPos(1, 1)
    buttons = {}
end

local function center(y, text, fg)
    text = tostring(text)
    local x = math.max(1, math.floor((W - #text) / 2) + 1)
    term.setCursorPos(x, y)
    term.setTextColor(fg or C.text)
    write(text:sub(1, W))
end

local function line(y)
    center(y, string.rep("-", math.min(W - 2, 28)), C.muted)
end

local function header(title, subtitle)
    clear()
    center(1, "BANK", C.accent)
    line(2)
    center(3, title or "БАНКОВСКАЯ СИСТЕМА", C.text)
    if subtitle then
        center(4, subtitle, C.muted)
    end
    line(5)
end

local function addButton(id, label, y, key)
    local width = math.min(W - 4, math.max(12, #label + 4))
    local x = math.floor((W - width) / 2) + 1

    color(C.button, C.bg)
    term.setCursorPos(x, y)
    write(string.rep(" ", width))

    local text = "[" .. label .. "]"
    local tx = x + math.floor((width - #text) / 2)
    term.setCursorPos(tx, y)
    write(text)

    buttons[#buttons + 1] = {
        id = id,
        x1 = x,
        x2 = x + width - 1,
        y = y,
        key = key
    }
end

local function waitChoice()
    while true do
        local event, a, b, c = os.pullEvent()

        if event == "mouse_click" then
            local x, y = b, c

            for _, btn in ipairs(buttons) do
                if y == btn.y and x >= btn.x1 and x <= btn.x2 then
                    return btn.id
                end
            end

        elseif event == "char" then
            for _, btn in ipairs(buttons) do
                if btn.key == a then
                    return btn.id
                end
            end
        end
    end
end

local function pause(message)
    header("УВЕДОМЛЕНИЕ")
    center(8, message or "Нажмите кнопку", C.text)
    addButton("back", "ПРОДОЛЖИТЬ", 12, "1")
    waitChoice()
end

local function inputScreen(title, prompt, hidden)
    header(title)
    center(8, prompt, C.text)
    center(10, "Введите значение с клавиатуры", C.muted)
    term.setCursorPos(3, 12)
    term.setTextColor(C.accent)

    if hidden then
        return read("*")
    end

    return read()
end

local function inputNumber(prompt)
    local value = inputScreen("ВВОД ДАННЫХ", prompt)
    return tonumber(value)
end

local function request(data)
    rednet.send(SERVER_ID, data, PROTOCOL)

    local deadline = os.clock() + TIMEOUT

    while true do
        local remaining = deadline - os.clock()

        if remaining <= 0 then
            return {
                ok = false,
                error = "Нет ответа от сервера"
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
                error = "Некорректный ответ сервера"
            }
        end

        if sender == nil then
            return {
                ok = false,
                error = "Нет ответа от сервера"
            }
        end
    end
end

local function showError(response)
    header("ОШИБКА")
    center(8, tostring(response.error or "Неизвестная ошибка"), C.error)
    addButton("back", "НАЗАД", 12, "1")
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
    local id = inputNumber("Банковский ID:")

    if not id or id < 1 or id % 1 ~= 0 then
        pause("Некорректный ID")
        return false
    end

    local pin = inputScreen("АВТОРИЗАЦИЯ", "Введите PIN:", true)

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
    local name = inputScreen("РЕГИСТРАЦИЯ", "Ваш игровой ник:")

    local pin = inputScreen("СОЗДАНИЕ PIN", "Придумайте 6 цифр:", true)

    if not pin:match("^%d%d%d%d%d%d$") then
        pause("PIN должен содержать 6 цифр")
        return false
    end

    local repeatPin = inputScreen("ПОДТВЕРЖДЕНИЕ", "Повторите PIN:", true)

    if pin ~= repeatPin then
        pause("PIN-коды не совпадают")
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

    header("СЧЁТ СОЗДАН")
    center(8, "ВАШ БАНКОВСКИЙ ID", C.muted)
    center(10, accountId, C.accent)
    center(12, "Начислено: " .. balance .. " BC", C.success)
    addButton("continue", "ПРОДОЛЖИТЬ", 16, "1")
    waitChoice()

    return true
end

local function showBalance()
    header("МОЙ СЧЁТ", accountName)

    if updateBalance() then
        center(8, "ДОСТУПНЫЙ БАЛАНС", C.muted)
        center(10, tostring(balance) .. " BC", C.accent)
        center(13, "Счёт №" .. tostring(accountId), C.text)
    end

    addButton("back", "НАЗАД", H - 2, "1")
    waitChoice()
end

local function transfer()
    header("ПЕРЕВОД СРЕДСТВ")
    center(8, "Доступно: " .. balance .. " BC", C.accent)

    local target = inputNumber("ID получателя:")

    if not target or target < 1 or target % 1 ~= 0 then
        pause("Некорректный ID получателя")
        return
    end

    local amount = inputNumber("Сумма перевода:")

    if not amount or amount < 1 or amount % 1 ~= 0 then
        pause("Некорректная сумма")
        return
    end

    if amount > balance then
        pause("Недостаточно средств")
        return
    end

    header("ПОДТВЕРЖДЕНИЕ")
    center(8, "Получатель: " .. target, C.text)
    center(10, "Сумма: " .. amount .. " BC", C.accent)
    center(12, "Подтвердить перевод?", C.text)

    addButton("yes", "ПОДТВЕРДИТЬ", 15, "1")
    addButton("no", "ОТМЕНА", 17, "2")

    if waitChoice() ~= "yes" then
        pause("Перевод отменён")
        return
    end

    local response = request({
        action = "TRANSFER",
        id = accountId,
        pin = accountPin,
        target = target,
        amount = amount
    })

    if response.ok then
        updateBalance()
        header("ПЕРЕВОД ВЫПОЛНЕН")
        center(9, "Успешно отправлено", C.success)
        center(11, amount .. " BC", C.accent)
        center(13, "Получатель: " .. target, C.text)
        addButton("back", "ГОТОВО", 17, "1")
        waitChoice()
    else
        showError(response)
    end
end

local function accountMenu()
    while accountId do
        header("ЛИЧНЫЙ КАБИНЕТ", accountName)

        center(7, "БАЛАНС", C.muted)
        center(8, tostring(balance) .. " BC", C.accent)
        center(10, "ID: " .. tostring(accountId), C.text)

        addButton("balance", "МОЙ СЧЁТ", 12, "1")
        addButton("transfer", "ПЕРЕВОД", 14, "2")
        addButton("refresh", "ОБНОВИТЬ БАЛАНС", 16, "3")
        addButton("logout", "ВЫЙТИ", 18, "0")

        local choice = waitChoice()

        if choice == "balance" then
            showBalance()

        elseif choice == "transfer" then
            transfer()

        elseif choice == "refresh" then
            if updateBalance() then
                pause("Баланс обновлён")
            end

        elseif choice == "logout" then
            accountId = nil
            accountPin = nil
            accountName = nil
            balance = 0
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
    header("ОШИБКА СВЯЗИ")
    center(9, "Модем не найден", C.error)
    return
end

while true do
    header("ДОБРО ПОЖАЛОВАТЬ")
    center(8, "ЭЛЕКТРОННЫЙ БАНК", C.muted)

    addButton("login", "ВОЙТИ В БАНК", 12, "1")
    addButton("register", "ОТКРЫТЬ СЧЁТ", 14, "2")

    center(H, "BANK  |  SECURE SYSTEM", C.muted)

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
