local DATA = "bank_data"
local BACKUP = DATA .. "/backup_before_registration_v2"
local MARKER = DATA .. "/registration_reset_v2_done"

if not fs.exists(DATA) then
    print("Bank data directory not found.")
    return
end

if fs.exists(MARKER) then
    print("Reset has already been completed.")
    return
end

if fs.exists(BACKUP) then
    print("Backup directory already exists. Reset cancelled.")
    return
end

fs.makeDir(BACKUP)

local files = {
    "accounts.db",
    "transactions.db",
    "settings.db",
    "registration_codes.db"
}

for _, name in ipairs(files) do
    local source = DATA .. "/" .. name
    if fs.exists(source) then
        fs.copy(source, BACKUP .. "/" .. name)
    end
end

local function save(path, value)
    local file = fs.open(path, "w")
    file.write(textutils.serialize(value))
    file.close()
end

save(DATA .. "/accounts.db", {
    nextId = 1,
    accounts = {}
})

save(DATA .. "/transactions.db", {})
save(DATA .. "/registration_codes.db", {
    codes = {}
})

local marker = fs.open(MARKER, "w")
marker.write(tostring(os.epoch("utc")))
marker.close()

print("OLD ACCOUNTS CLEARED")
print("Old transaction history cleared.")
print("Account IDs will start at 1.")
print("Starting balance remains in settings.db.")
print("Backup: " .. BACKUP)
print("Reset completed. Do not run this program again.")
