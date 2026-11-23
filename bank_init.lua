
-- BANK: database initialization
local root = "bank_data"

if not fs.exists(root) then
    fs.makeDir(root)
end

local files = {
    ["accounts.db"] = {
        nextId = 100001,
        accounts = {}
    },
    ["transactions.db"] = {},
    ["settings.db"] = {
        startingBalance = 500,
        currency = "BC",
        bankName = "Bank"
    }
}

for name, data in pairs(files) do
    local path = fs.combine(root, name)

    if not fs.exists(path) then
        local file = fs.open(path, "w")
        file.write(textutils.serialize(data))
        file.close()
        print("Created: " .. path)
    else
        print("Preserved: " .. path)
    end
end

print("")
print("BANK DATABASE READY")
