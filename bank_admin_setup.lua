local path = "bank_data/admin_settings.db"
if not fs.exists("bank_data") then fs.makeDir("bank_data") end
if fs.exists(path) then
    print("An administrator password is already configured.")
    print("Enter a new password to replace it.")
else
    print("Create the administrator password.")
end
write("New password: ")
local first = read("*")
write("Confirm password: ")
local second = read("*")
if #first < 6 then
    print("Password must contain at least 6 characters.")
    return
end
if first ~= second then
    print("Passwords do not match.")
    return
end
local file = fs.open(path, "w")
file.write(textutils.serialize({password = first}))
file.close()
print("Administrator password saved.")
