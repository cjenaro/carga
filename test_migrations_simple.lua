#!/usr/bin/env lua

local carga = require("carga")

-- Setup test environment
local test_dir = "test_migrations_simple"
local db_path = test_dir .. "/test.sqlite3"
local migrations_path = test_dir .. "/db/migrate"

-- Cleanup function
local function cleanup()
    os.execute("rm -rf " .. test_dir)
end

-- Setup
cleanup()
os.execute("mkdir -p " .. migrations_path)

carga.configure({
    database_path = db_path,
    enable_logging = true
})
carga.connect()

carga.Migration.configure({
    migrations_path = migrations_path
})

print("🧪 Testing Migration System (Simple)")
print("=" .. string.rep("=", 40))

-- Manually create migration files with proper timestamps
print("\n📝 Creating migration files manually...")

-- Migration 1: Create users (timestamp: 001)
local migration1_path = migrations_path .. "/001_create_users.lua"
local migration1_content = [[return {
    up = function(db)
        db:create_table("users", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            name = "TEXT NOT NULL",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
    end,
    
    down = function(db)
        db:drop_table("users")
    end
}
]]

local file1 = io.open(migration1_path, "w")
file1:write(migration1_content)
file1:close()

-- Migration 2: Create posts (timestamp: 002)
local migration2_path = migrations_path .. "/002_create_posts.lua"
local migration2_content = [[return {
    up = function(db)
        db:create_table("posts", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            title = "TEXT NOT NULL",
            content = "TEXT",
            user_id = "INTEGER",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
    end,
    
    down = function(db)
        db:drop_table("posts")
    end
}
]]

local file2 = io.open(migration2_path, "w")
file2:write(migration2_content)
file2:close()

-- Migration 3: Add email (timestamp: 003)
local migration3_path = migrations_path .. "/003_add_email_to_users.lua"
local migration3_content = [[return {
    up = function(db)
        db:add_column("users", "email", "TEXT UNIQUE")
    end,
    
    down = function(db)
        db:drop_column("users", "email")
    end
}
]]

local file3 = io.open(migration3_path, "w")
file3:write(migration3_content)
file3:close()

print("Created migration files:")
print("  - " .. migration1_path)
print("  - " .. migration2_path)
print("  - " .. migration3_path)

-- Test migration status
print("\n📊 Initial migration status...")
carga.Migration.status()

-- Run migrations
print("\n🚀 Running migrations...")
carga.Migration.migrate()

-- Check tables
print("\n🔍 Checking created tables...")
print("Users table exists:", carga.Database.table_exists("users"))
print("Posts table exists:", carga.Database.table_exists("posts"))

-- Check schema
local users_schema = carga.Database.get_table_schema("users")
print("Users table columns:")
for _, column in ipairs(users_schema) do
    print("  - " .. column.name .. " (" .. column.type .. ")")
end

-- Test with data
print("\n📝 Testing with data...")
carga.Database.execute("INSERT INTO users (name, email) VALUES (?, ?)", { "Alice", "alice@example.com" })
carga.Database.execute("INSERT INTO posts (title, content, user_id) VALUES (?, ?, ?)", { "First Post", "Hello World", 1 })

local users_count = carga.Database.query("SELECT COUNT(*) as count FROM users").rows[1].count
local posts_count = carga.Database.query("SELECT COUNT(*) as count FROM posts").rows[1].count

print("Users count:", users_count)
print("Posts count:", posts_count)

-- Test rollback
print("\n🔄 Testing rollback...")
carga.Migration.rollback()

-- Check schema after rollback
local users_schema_after = carga.Database.get_table_schema("users")
print("Users columns after rollback:")
for _, column in ipairs(users_schema_after) do
    print("  - " .. column.name .. " (" .. column.type .. ")")
end

-- Final status
print("\n📊 Final migration status...")
carga.Migration.status()

-- Cleanup
print("\n🧹 Cleaning up...")
carga.disconnect()
cleanup()

print("\n✅ Migration tests completed!")