#!/usr/bin/env lua

print("Starting simple test...")

local carga = require("carga")
print("✅ Carga loaded, version:", carga.VERSION)

carga.configure({
    database_path = "test_simple.sqlite3",
    enable_logging = true
})
print("✅ Configuration set")

carga.connect()
print("✅ Database connected")

-- Test table creation
local success = carga.Database.create_table("test_users", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    name = "TEXT NOT NULL"
})
print("✅ Table creation result:", success.success)

-- Test User model
local User = carga.Model:extend("User")
User.table_name = "test_users"
print("✅ User model created")

-- Test basic operations
local user = User:new({ name = "Test User" })
print("✅ User instance created:", user.name)

local saved = user:save()
print("✅ User save result:", saved)

if saved then
    print("✅ User ID after save:", user.id)
end

-- Test finding
local found_user = User:find(1)
if found_user then
    print("✅ Found user:", found_user.name)
else
    print("❌ User not found")
end

-- Count users
local count = User:count()
print("✅ Total users:", count)

-- Cleanup
carga.disconnect()
os.remove("test_simple.sqlite3")
print("✅ Test completed successfully!")