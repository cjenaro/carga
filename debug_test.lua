#!/usr/bin/env lua

local carga = require("carga")

carga.configure({
    database_path = "debug.sqlite3",
    enable_logging = false
})
carga.connect()

carga.Database.create_table("debug_users", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    name = "TEXT NOT NULL"
})

local User = carga.Model:extend("User")
User.table_name = "debug_users"

local user = User:new({ name = "Debug User" })

print("=== Debug Info ===")
print("user._attributes:", user._attributes)
if user._attributes then
    for k, v in pairs(user._attributes) do
        print("  " .. k .. ":", v)
    end
end

print("user.name via get_attribute:", user:get_attribute("name"))
print("user.name via direct access:", user.name)

user:save()

print("After save:")
print("user.id via get_attribute:", user:get_attribute("id"))
print("user.id via direct access:", user.id)
if user._attributes then
    for k, v in pairs(user._attributes) do
        print("  " .. k .. ":", v)
    end
end

carga.disconnect()
os.remove("debug.sqlite3")