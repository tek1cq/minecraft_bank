local root = "bank_data"
local accountsPath = root .. "/accounts.db"
local historyPath = root .. "/transactions.db"
local markerPath = root .. "/id_migration_done"
if fs.exists(markerPath) then
    print("Migration was already completed.")
    return
end
if not fs.exists(accountsPath) then
    print("ERROR: Accounts database not found.")
    return
end
local function load(path)
    local f = fs.open(path, "r")
    if not f then error("Cannot open " .. path) end
    local data = textutils.unserialize(f.readAll())
    f.close()
    if type(data) ~= "table" then
        error("Invalid database: " .. path)
    end
    return data
end
local function save(path, data)
    local f = fs.open(path, "w")
    if not f then error("Cannot write " .. path) end
    f.write(textutils.serialize(data))
    f.close()
end
local db = load(accountsPath)
local history = load(historyPath)
local oldIds = {}
for oldId in pairs(db.accounts) do
    table.insert(oldIds, tonumber(oldId))
end
table.sort(oldIds)
local mapping = {}
local newAccounts = {}
for index, oldId in ipairs(oldIds) do
    local account = db.accounts[tostring(oldId)]
    local newId = index
    mapping[tostring(oldId)] = newId
    account.id = newId
    newAccounts[tostring(newId)] = account
end
for _, entry in ipairs(history) do
    for _, field in ipairs({"id", "from", "to", "target"}) do
        local oldValue = entry[field]
        if oldValue ~= nil and mapping[tostring(oldValue)] then
            entry[field] = mapping[tostring(oldValue)]
        end
    end
end
db.accounts = newAccounts
db.nextId = #oldIds + 1
save(accountsPath, db)
save(historyPath, history)
local marker = fs.open(markerPath, "w")
marker.write("Completed")
marker.close()
print("")
print("ID MIGRATION COMPLETE")
print("Accounts migrated: " .. #oldIds)
print("Next available ID: " .. db.nextId)
