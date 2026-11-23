term.clear()
term.setCursorPos(1, 1)

local computerId = os.getComputerID()
local modemFound = false

print("=== BANK NETWORK TEST ===")
print("Computer ID: " .. computerId)

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

print("Modem: READY")
print("")

if computerId == 203 then
    print("BANK SERVER STARTED")
    print("Waiting for terminal 204...")
    print("")

    while true do
        local sender, message = rednet.receive("bank_test")

        if sender == 204 and message == "PING" then
            print("Received message from 204")
            rednet.send(204, "BANK_OK", "bank_test")
            print("Reply sent!")
        else
            print("Unknown message received")
        end
    end
elseif computerId == 204 then
    print("BANK TERMINAL")
    print("Sending request to 203...")

    rednet.send(203, "PING", "bank_test")

    local sender, message = rednet.receive("bank_test", 10)

    if sender == 203 and message == "BANK_OK" then
        print("")
        print("SUCCESS!")
        print("Server 203 responded.")
    else
        print("")
        print("ERROR: NO RESPONSE")
        print("Check network connection.")
    end
else
    print("UNKNOWN COMPUTER")
end
