#!/usr/bin/env lua

-- Carga ORM Example
-- Demonstrates basic usage of the Active Record ORM

local carga = require("carga")

-- Configure database
carga.configure({
    database_path = "example.sqlite3",
    enable_logging = true
})

-- Connect to database
carga.connect()

-- Create users table if it doesn't exist
if not carga.Database.table_exists("users") then
    print("📋 Creating users table...")
    carga.Database.create_table("users", {
        id = "INTEGER PRIMARY KEY AUTOINCREMENT",
        name = "TEXT NOT NULL",
        email = "TEXT UNIQUE NOT NULL",
        age = "INTEGER",
        active = "BOOLEAN DEFAULT 1",
        created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP",
        updated_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
    })
    
    carga.Database.add_index("users", "email")
end

-- Define User model
local User = carga.Model:extend("User")
User.table_name = "users"

-- Add validations
User.validations = {
    name = { required = true, min_length = 2, max_length = 50 },
    email = { required = true, format = "email", unique = true },
    age = { type = "number", min = 0, max = 150 }
}

-- Custom validation
function User:validate()
    if self.email and self.email:match("@spam%.com$") then
        self:add_error("email", "spam.com emails are not allowed")
    end
end

-- Callbacks
function User:before_save()
    self.updated_at = os.date("!%Y-%m-%d %H:%M:%S")
    if self.email then
        self.email = string.lower(self.email)
    end
end

function User:after_create()
    print("👋 Welcome " .. self.name .. "! Your account has been created.")
end

-- Demonstration
print("🚀 Carga ORM Example")
print("=" .. string.rep("=", 40))

-- Clear existing data for demo
User:where("1=1"):destroy_all()

-- Create users
print("\n📝 Creating users...")

local alice = User:create({
    name = "Alice Johnson",
    email = "ALICE@EXAMPLE.COM",
    age = 28
})

local bob = User:create({
    name = "Bob Smith", 
    email = "bob@example.com",
    age = 35
})

local charlie = User:create({
    name = "Charlie Brown",
    email = "charlie@example.com",
    age = 22
})

-- Demonstrate validation failure
print("\n❌ Attempting to create invalid user...")
local invalid_user = User:new({
    name = "X", -- Too short
    email = "not-an-email", -- Invalid format
    age = -5 -- Invalid age
})

if not invalid_user:save() then
    print("Validation failed as expected:")
    for field, errors in pairs(invalid_user:get_errors()) do
        for _, error in ipairs(errors) do
            print("  • " .. field .. ": " .. error)
        end
    end
end

-- Query examples
print("\n🔍 Querying users...")

-- Find all users
local all_users = User:all()
print("Total users: " .. #all_users)

-- Find by ID
local user = User:find(alice.id)
print("Found user by ID: " .. user.name)

-- Find by conditions
local bob_found = User:find_by({ name = "Bob Smith" })
print("Found user by name: " .. bob_found.email)

-- Complex queries
local young_users = User:where("age < ?", { 30 }):order("age"):all()
print("Young users (age < 30):")
for _, u in ipairs(young_users) do
    print("  • " .. u.name .. " (" .. u.age .. " years old)")
end

-- Count
local total_count = User:count()
local young_count = User:where("age < ?", { 30 }):count()
print("Total users: " .. total_count .. ", Young users: " .. young_count)

-- Update example
print("\n✏️  Updating user...")
alice.age = 29
alice:save()
print("Updated Alice's age to " .. alice.age)

-- Bulk update
User:where("age > ?", { 30 }):update_all({ active = false })
print("Deactivated users over 30")

-- Show final state
print("\n📊 Final user list:")
local final_users = User:order("name"):all()
for _, u in ipairs(final_users) do
    local status = u.active and "active" or "inactive"
    print("  • " .. u.name .. " (" .. u.age .. ") - " .. status)
end

-- Transaction example
print("\n💳 Transaction example...")
local initial_count = User:count()

-- Successful transaction
carga.transaction(function()
    User:create({ name = "David Wilson", email = "david@example.com", age = 40 })
    User:create({ name = "Eve Davis", email = "eve@example.com", age = 33 })
end)

print("After successful transaction: " .. User:count() .. " users (was " .. initial_count .. ")")

-- Failed transaction (will rollback)
local before_failed = User:count()
local success, error_msg = pcall(function()
    carga.transaction(function()
        User:create({ name = "Frank Miller", email = "frank@example.com", age = 45 })
        error("Simulated error - this will rollback the transaction")
    end)
end)

print("After failed transaction: " .. User:count() .. " users (still " .. before_failed .. ")")

-- Raw SQL example
print("\n🔧 Raw SQL example...")
local result = User:query("SELECT name, age FROM users WHERE age > ? ORDER BY age DESC", { 25 })
print("Users over 25 (raw SQL):")
for _, row in ipairs(result.rows) do
    print("  • " .. row.name .. " (" .. row.age .. ")")
end

-- Cleanup
print("\n🧹 Cleaning up...")
User:where("1=1"):destroy_all()
print("Deleted all users")

-- Disconnect
carga.disconnect()
print("\n✅ Example completed successfully!")