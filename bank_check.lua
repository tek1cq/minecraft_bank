
term.clear()
term.setCursorPos(1, 1)

print("================================")
print("        BANK SYSTEM")
print("      NETWORK DIAGNOSTICS")
print("================================")
print("")

print("Computer ID: " .. os.getComputerID())
print("")

local names = peripheral.getNames()

if #names == 0 then
    print("No peripherals detected.")
end

for _, name in ipairs(names) do
    print("Device: " .. name)

    local types = peripheral.getType(name)

    if type(types) == "table" then
        print("Type: " .. table.concat(types, ", "))
    else
        print("Type: " .. tostring(types))
    end

    local modem = peripheral.wrap(name)

    if modem and type(modem.isWireless) == "function" then
        print("Wireless: " .. tostring(modem.isWireless()))
    end

    print("----------------------------")
end

print("DIAGNOSTICS COMPLETED")
