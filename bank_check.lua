term.clear()
term.setCursorPos(1, 1)

print("================================")
print("          BANK SYSTEM")
print("      NETWORK DIAGNOSTICS")
print("================================")
print("")
print("Computer ID: " .. os.getComputerID())
print("")

local peripherals = peripheral.getNames()

if #peripherals == 0 then
    print("No peripherals detected.")
end

for _, name in ipairs(peripherals) do
    print("Device: " .. name)

    local deviceTypes = peripheral.getType(name)
    if type(deviceTypes) == "table" then
        print("Type: " .. table.concat(deviceTypes, ", "))
    else
        print("Type: " .. tostring(deviceTypes))
    end

    local device = peripheral.wrap(name)
    if device and type(device.isWireless) == "function" then
        print("Wireless: " .. tostring(device.isWireless()))
    end

    print("----------------------------")
end

print("DIAGNOSTICS COMPLETED")
