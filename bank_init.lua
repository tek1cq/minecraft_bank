local DATA_DIRECTORY = "bank_data"

local initialFiles = {
    ["accounts.db"] = {
        nextId = 100001,
        accounts = {}
    },
    ["transactions.db"] = {},
    ["registration_codes.db"] = {
        codes = {}
    },
    ["settings.db"] = {
        startingBalance = 500,
        currency = "BC",
        bankName = "Bank"
    }
}

if not fs.exists(DATA_DIRECTORY) then
    fs.makeDir(DATA_DIRECTORY)
end

for fileName, data in pairs(initialFiles) do
    local path = fs.combine(DATA_DIRECTORY, fileName)

    if fs.exists(path) then
        print("Preserved: " .. path)
    else
        local file = fs.open(path, "w")
        file.write(textutils.serialize(data))
        file.close()

        print("Created: " .. path)
    end
end

print("")
print("BANK DATABASE READY")
