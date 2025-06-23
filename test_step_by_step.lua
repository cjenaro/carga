#!/usr/bin/env lua

local carga = require("carga")

carga.configure({
    database_path = "step_test.sqlite3",
    enable_logging = true
})
carga.connect()

-- Create table
carga.Database.create_table("step_users", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    name = "TEXT NOT NULL",
    email = "TEXT UNIQUE",
    age = "INTEGER"
})

-- Define model
local User = carga.Model:extend("User")
User.table_name = "step_users"

print("=== Step 1: Basic creation ===")
local user1 = User:new({ name = "Alice", email = "alice@example.com", age = 28 })
print("Created user:", user1.name, user1.email, user1.age)

print("\n=== Step 2: Save user ===")
local saved = user1:save()
print("Save result:", saved)
print("User ID:", user1.id)

print("\n=== Step 3: Find user ===")
local found = User:find(user1.id)
print("Found user:", found and found.name or "nil")

print("\n=== Step 4: Create with validations ===")
User.validations = {
    name = { required = true, min_length = 2 },
    email = { format = "email" }
}

local user2 = User:new({ name = "Bob", email = "bob@example.com" })
local saved2 = user2:save()
print("User2 save result:", saved2)

print("\n=== Step 5: Invalid user ===")
local invalid_user = User:new({ name = "X", email = "not-email" })
local saved_invalid = invalid_user:save()
print("Invalid user save result:", saved_invalid)
if invalid_user:has_errors() then
    print("Errors:")
    for field, errors in pairs(invalid_user:get_errors()) do
        for _, error in ipairs(errors) do
            print("  " .. field .. ": " .. error)
        end
    end
end

print("\n=== Step 6: Query operations ===")
local all_users = User:all()
print("Total users:", #all_users)

local count = User:count()
print("Count:", count)

-- Cleanup
carga.disconnect()
os.remove("step_test.sqlite3")
print("\n✅ Step-by-step test completed!")