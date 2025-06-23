#!/usr/bin/env lua

local carga = require("carga")

-- Setup test environment
local test_dir = "test_migrations_temp"
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
    enable_logging = false
})
carga.connect()

carga.Migration.configure({
    migrations_path = migrations_path
})

print("🧪 Testing Migration System")
print("=" .. string.rep("=", 40))

-- Test 1: Generate migration files
print("\n📝 Testing migration generation...")

local migration1_path = carga.Migration.generate("create_users")
local migration2_path = carga.Migration.generate("create_posts")
local migration3_path = carga.Migration.generate("add_email_to_users")

print("Generated migrations:")
print("  - " .. migration1_path)
print("  - " .. migration2_path)
print("  - " .. migration3_path)

-- Test 2: Write actual migration content
print("\n✏️  Writing migration content...")

-- Migration 1: Create users table
local migration1_content = [[-- Migration: create_users

return {
    up = function(db)
        db:create_table("users", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            name = "TEXT NOT NULL",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
        
        db:add_index("users", "name")
    end,
    
    down = function(db)
        db:drop_table("users")
    end
}
]]

local file1 = io.open(migration1_path, "w")
file1:write(migration1_content)
file1:close()

-- Migration 2: Create posts table
local migration2_content = [[-- Migration: create_posts

return {
    up = function(db)
        db:create_table("posts", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            title = "TEXT NOT NULL",
            content = "TEXT",
            user_id = "INTEGER",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
        
        db:add_index("posts", "user_id")
    end,
    
    down = function(db)
        db:drop_table("posts")
    end
}
]]

local file2 = io.open(migration2_path, "w")
file2:write(migration2_content)
file2:close()

-- Migration 3: Add email column
local migration3_content = [[-- Migration: add_email_to_users

return {
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

print("Migration content written")

-- Test 3: Check migration status
print("\n📊 Testing migration status...")
carga.Migration.status()

-- Test 4: Run migrations
print("\n🚀 Testing migration execution...")
carga.Migration.migrate()

-- Test 5: Check tables were created
print("\n🔍 Checking created tables...")
local users_exists = carga.Database.table_exists("users")
local posts_exists = carga.Database.table_exists("posts")
print("Users table exists:", users_exists)
print("Posts table exists:", posts_exists)

-- Test 6: Check schema
if users_exists then
    local users_schema = carga.Database.get_table_schema("users")
    print("Users table columns:")
    for _, column in ipairs(users_schema) do
        print("  - " .. column.name .. " (" .. column.type .. ")")
    end
end

-- Test 7: Insert test data
print("\n📝 Testing with actual data...")
carga.Database.execute("INSERT INTO users (name, email) VALUES (?, ?)", { "Alice", "alice@example.com" })
carga.Database.execute("INSERT INTO users (name, email) VALUES (?, ?)", { "Bob", "bob@example.com" })
carga.Database.execute("INSERT INTO posts (title, content, user_id) VALUES (?, ?, ?)", { "First Post", "Hello World", 1 })

local users_result = carga.Database.query("SELECT * FROM users")
local posts_result = carga.Database.query("SELECT * FROM posts")

print("Users count:", users_result.count)
print("Posts count:", posts_result.count)

-- Test 8: Check migration status after running
print("\n📊 Migration status after running...")
carga.Migration.status()

-- Test 9: Test rollback
print("\n🔄 Testing rollback...")
carga.Migration.rollback()

-- Check if email column was removed
local users_schema_after_rollback = carga.Database.get_table_schema("users")
print("Users columns after rollback:")
for _, column in ipairs(users_schema_after_rollback) do
    print("  - " .. column.name .. " (" .. column.type .. ")")
end

-- Test 10: Test migration status after rollback
print("\n📊 Migration status after rollback...")
carga.Migration.status()

-- Test 11: Test reset
print("\n🔄 Testing reset...")
carga.Migration.reset()

-- Check if tables were dropped
local users_exists_after_reset = carga.Database.table_exists("users")
local posts_exists_after_reset = carga.Database.table_exists("posts")
print("Users table exists after reset:", users_exists_after_reset)
print("Posts table exists after reset:", posts_exists_after_reset)

-- Test 12: Final migration status
print("\n📊 Final migration status...")
carga.Migration.status()

-- Test 13: Re-run migrations
print("\n🔄 Re-running all migrations...")
carga.Migration.migrate()

-- Final status
print("\n📊 Final status after re-migration...")
carga.Migration.status()

-- Cleanup
print("\n🧹 Cleaning up...")
carga.disconnect()
cleanup()

print("\n✅ Migration tests completed!")