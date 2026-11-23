local SERVER_ID = 203
local PROTOCOL = "bank"
local TIMEOUT = 8
local token
local buttons = {}
local width, height

local function style(bg, fg)
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
end

local function clear(title, subtitle)
    width, height = term.getSize()
    buttons = {}
    style(colors.black, colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.orange)
    term.write("BANK ADMIN")
    term.setCursorPos(1, 2)
    term.write(string.rep("=", width))
    term.setTextColor(colors.white)
    local x = math.max(1, math.floor((width - #title) / 2) + 1)
    term.setCursorPos(x, 4)
    term.write(title)
    if subtitle then
        term.setTextColor(colors.lightGray)
        term.setCursorPos(1, 5)
        term.write(subtitle:sub(1, width))
    end
end

local function text(y, value, color)
    if y < 1 or y > height then return end
    value = tostring(value or "")
    if #value > width then value = value:sub(1, width) end
    style(colors.black, color or colors.white)
    term.setCursorPos(1, y)
    term.clearLine()
    term.write(value)
end

local function button(id, label, y, primary)
    if y < 1 or y > height then return end
    local w = math.min(width - 2, math.max(12, #label + 4))
    local x = math.floor((width - w) / 2) + 1
    style(primary and colors.orange or colors.gray, primary and colors.black or colors.white)
    term.setCursorPos(x, y)
    term.write(string.rep(" ", w))
    term.setCursorPos(x + math.floor((w - #label) / 2), y)
    term.write(label:sub(1, w - 2))
    buttons[#buttons + 1] = {id = id, x1 = x, x2 = x + w - 1, y = y}
    style(colors.black, colors.white)
end

local function wait()
    while true do
        local _, b, x, y = os.pullEvent("mouse_click")
        if b == 1 then
            for _, item in ipairs(buttons) do
                if x >= item.x1 and x <= item.x2 and y == item.y then
                    return item.id
                end
            end
        end
    end
end

local function ask(title, prompt, hidden)
    clear(title, prompt)
    text(9, "> " .. prompt, colors.lightGray)
    style(colors.gray, colors.white)
    term.setCursorPos(3, 12)
    term.write(string.rep(" ", math.max(1, width - 4)))
    term.setCursorPos(4, 12)
    term.setCursorBlink(true)
    local value = hidden and read("*") or read()
    term.setCursorBlink(false)
    style(colors.black, colors.white)
    return value
end

local function request(action, data)
    data = data or {}
    data.action = action
    data.token = token
    rednet.send(SERVER_ID, data, PROTOCOL)
    local sender, response = rednet.receive(PROTOCOL, TIMEOUT)
    if sender ~= SERVER_ID or type(response) ~= "table" then
        return {ok = false, error = "SERVER NOT RESPONDING"}
    end
    return response
end

local function notice(value)
    clear("NOTICE")
    text(9, tostring(value), colors.yellow)
    button("ok", "CONTINUE", height - 3, true)
    wait()
end

local function result(response)
    if not response.ok then
        notice(response.error or "REQUEST FAILED")
        return false
    end
    return true
end

local function login()
    local password = ask("ADMIN LOGIN", "Administrator password", true)
    local response = request("ADMIN_LOGIN", {password = password})
    if not response.ok then
        notice(response.error or "LOGIN FAILED")
        return false
    end
    token = response.token
    return true
end

local function dashboard()
    local r = request("ADMIN_STATS")
    if not result(r) then return end
    clear("DASHBOARD", "BANK OVERVIEW")
    text(8, "ACCOUNTS       " .. r.accounts, colors.white)
    text(10, "CIRCULATION    " .. r.total .. " BC", colors.yellow)
    text(12, "BLOCKED        " .. r.blocked, colors.red)
    button("accounts", "ACCOUNTS", 15)
    button("money", "MONEY", 16)
    button("history", "HISTORY", 17)
    button("registration", "REGISTRATIONS", 18)
    button("exit", "LOCK / EXIT", 19, true)
    return wait()
end

local showHistory

local function accounts()
    local id = ask("FIND ACCOUNT", "Enter Bank ID")
    local r = request("ADMIN_ACCOUNT", {id = id})
    if not result(r) then return end
    clear("ACCOUNT PROFILE", "BANK ID " .. tostring(r.id))
    text(8, "PLAYER  " .. r.name)
    text(10, "BALANCE " .. r.balance .. " BC", colors.yellow)
    text(12, r.blocked and "STATUS  BLOCKED" or "STATUS  ACTIVE", r.blocked and colors.red or colors.lime)
    button("block", r.blocked and "UNBLOCK" or "BLOCK", 15, true)
    button("history", "ACCOUNT HISTORY", 17)
    button("back", "BACK", 19)
    local choice = wait()
    if choice == "block" then
        local changed = request("ADMIN_TOGGLE_BLOCK", {id = id})
        if result(changed) then notice(changed.blocked and "ACCOUNT BLOCKED" or "ACCOUNT UNBLOCKED") end
    elseif choice == "history" then
        showHistory(id)
    end
end

local function historyView(id, title)
    local r = request("ADMIN_HISTORY", {id = id or "*"})
    if not result(r) then return end
    local page = 1
    local perPage = 4
    while true do
        clear(title, "SELECT AN OPERATION")
        local totalPages = math.max(1, math.ceil(#r.transactions / perPage))
        if #r.transactions == 0 then
            text(9, "NO TRANSACTIONS", colors.lightGray)
        else
            local first = (page - 1) * perPage + 1
            local last = math.min(#r.transactions, first + perPage - 1)
            local y = 8
            for i = first, last do
                local item = r.transactions[i]
                local label = tostring(item.action)
                if item.amount and item.amount > 0 then label = label .. " " .. tostring(item.amount) .. " BC" end
                button("entry:" .. i, label, y)
                y = y + 2
            end
        end
        text(height - 3, "PAGE " .. page .. "/" .. totalPages, colors.lightGray)
        if page > 1 then button("prev", "PREV", height - 2) end
        if page < totalPages then button("next", "NEXT", height - 2) end
        button("back", "BACK", height, true)
        local choice = wait()
        if choice == "back" then return end
        if choice == "prev" then page = math.max(1, page - 1)
        elseif choice == "next" then page = math.min(totalPages, page + 1)
        elseif type(choice) == "string" and choice:sub(1, 6) == "entry:" then
            local item = r.transactions[tonumber(choice:sub(7))]
            if item then
                clear("OPERATION DETAILS")
                text(7, "ACTION: " .. tostring(item.action), colors.yellow)
                if item.time then
                    text(8, os.date("%d.%m.%Y %H:%M", math.floor(item.time / 1000)))
                end
                text(10, "FROM: " .. tostring(item.fromName or item.from or "-"))
                text(11, "TO: " .. tostring(item.toName or item.to or "-"))
                if item.amount and item.amount > 0 then
                    text(13, "AMOUNT: " .. tostring(item.amount) .. " BC", colors.lime)
                else
                    text(13, "AMOUNT: -")
                end
                button("back", "BACK TO HISTORY", height - 2, true)
                wait()
            end
        end
    end
end

showHistory = function(id)
    historyView(id, "ACCOUNT HISTORY")
end

local function money()
    local id = ask("MONEY OPERATIONS", "Player Bank ID")
    local amount = tonumber(ask("MONEY OPERATIONS", "Amount in BC"))
    if not amount then notice("INVALID AMOUNT") return end
    clear("CONFIRM OPERATION", "CHOOSE ACTION")
    button("add", "ADD FUNDS", 12, true)
    button("remove", "REMOVE FUNDS", 14)
    button("back", "CANCEL", 17)
    local choice = wait()
    if choice == "back" then return end
    local r = request("ADMIN_ADJUST", {id = id, amount = amount, mode = choice == "add" and "ADD" or "REMOVE"})
    if result(r) then notice("SUCCESS. NEW BALANCE: " .. r.balance .. " BC") end
end

local function registration()
    clear("REGISTRATION", "ACCOUNT AND CODE MANAGEMENT")
    button("create", "CREATE ACCOUNT", 10, true)
    button("codes", "VIEW CODES", 13)
    button("revoke", "REVOKE CODE", 16)
    button("back", "BACK", 19)
    local choice = wait()
    if choice == "create" then
        local nickname = ask("CREATE ACCOUNT", "Minecraft nickname")
        local r = request("ADMIN_CREATE_ACCOUNT", {nickname = nickname})
        if result(r) then
            clear("ACCOUNT RESERVED")
            text(8, "PLAYER: " .. r.nickname)
            text(10, "BANK ID: " .. r.id, colors.yellow)
            text(12, "CODE: " .. r.code, colors.lime)
            button("ok", "DONE", height - 3, true)
            wait()
        end
    elseif choice == "codes" then
        local r = request("ADMIN_CODES")
        if not result(r) then return end
        clear("REGISTRATION CODES", "LATEST CODES")
        local y = 8
        for i = math.max(1, #r.codes - 4), #r.codes do
            local item = r.codes[i]
            local status = item.used and "USED" or (item.revoked and "REVOKED" or "READY")
            text(y, "ID " .. tostring(item.id) .. " " .. tostring(item.nickname))
            y = y + 1
            text(y, tostring(item.code) .. " " .. status, colors.lime)
            y = y + 1
        end
        if #r.codes == 0 then text(10, "NO CODES") end
        button("back", "BACK", height - 2, true)
        wait()
    elseif choice == "revoke" then
        local code = ask("REVOKE CODE", "Registration code")
        local r = request("ADMIN_REVOKE_CODE", {code = code})
        if result(r) then notice("CODE REVOKED") end
    end
end

local function globalHistory()
    historyView("*", "TRANSACTION HISTORY")
end

local opened = false
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
        rednet.open(name)
        opened = true
    end
end
if not opened then
    print("NO MODEM FOUND")
    return
end

if not login() then return end
while true do
    local choice = dashboard()
    if choice == "accounts" then
        accounts()
    elseif choice == "money" then
        money()
    elseif choice == "registration" then
        registration()
    elseif choice == "history" then
        globalHistory()
    elseif choice == "exit" then
        token = nil
        break
    end
end
