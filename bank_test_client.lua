local PROTOCOL = "bank"
term.clear()
term.setCursorPos(1, 1)
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
print("========== BANK ==========")
print("TEST REGISTRATION")
print("")
write("Minecraft nickname: ")
local nickname = read()
write("Temporary 6-digit PIN: ")
local pin = read("*")
print("")
print("Sending registration request...")
rednet.send(203, {
    action = "REGISTER",
    name = nickname,
    pin = pin
}, PROTOCOL)
local sender, response = rednet.receive(PROTOCOL, 10)
if not response then
    print("ERROR: SERVER TIMEOUT")
    return
end
if response.ok then
    print("")
    print("ACCOUNT CREATED!")
    print("--------------------------")
    print("Player: " .. nickname)
    print("Bank ID: " .. response.id)
    print("Balance: " .. response.balance .. " BC")
    print("--------------------------")
    print("")
    print("Checking balance...")
    rednet.send(203, {
        action = "BALANCE",
        id = response.id,
        pin = pin
    }, PROTOCOL)
    local _, balance = rednet.receive(PROTOCOL, 10)
    if balance and balance.ok then
        print("Balance confirmed: " .. balance.balance .. " BC")
    else
        print("Balance check failed.")
    end
else
    print("REGISTRATION FAILED:")
    print(response.error or "UNKNOWN ERROR")
end
