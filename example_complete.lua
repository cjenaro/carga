#!/usr/bin/env lua

-- Carga ORM Complete Feature Showcase
-- Demonstrates all implemented features

local carga = require("carga")

print("🚀 Carga ORM - Complete Feature Showcase")
print("=" .. string.rep("=", 50))

-- Configure and connect
carga.configure({
    database_path = "showcase.sqlite3",
    enable_logging = false
})
carga.connect()

-- === MIGRATIONS ===
print("\n📋 1. MIGRATION SYSTEM")

-- Configure migrations
carga.Migration.configure({
    migrations_path = "showcase_migrations"
})

-- Create migration directory and files
os.execute("mkdir -p showcase_migrations")

-- Create users migration
local users_migration = [[return {
    up = function(db)
        db:create_table("users", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            name = "TEXT NOT NULL",
            email = "TEXT UNIQUE",
            age = "INTEGER",
            company_id = "INTEGER",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
        db:add_index("users", "email")
    end,
    down = function(db)
        db:drop_table("users")
    end
}]]

local file = io.open("showcase_migrations/001_create_users.lua", "w")
file:write(users_migration)
file:close()

-- Create companies migration
local companies_migration = [[return {
    up = function(db)
        db:create_table("companies", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            name = "TEXT NOT NULL",
            industry = "TEXT"
        })
    end,
    down = function(db)
        db:drop_table("companies")
    end
}]]

file = io.open("showcase_migrations/002_create_companies.lua", "w")
file:write(companies_migration)
file:close()

-- Create posts migration
local posts_migration = [[return {
    up = function(db)
        db:create_table("posts", {
            id = "INTEGER PRIMARY KEY AUTOINCREMENT",
            title = "TEXT NOT NULL",
            content = "TEXT",
            user_id = "INTEGER NOT NULL",
            published = "BOOLEAN DEFAULT 0",
            created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
        db:add_index("posts", "user_id")
    end,
    down = function(db)
        db:drop_table("posts")
    end
}]]

file = io.open("showcase_migrations/003_create_posts.lua", "w")
file:write(posts_migration)
file:close()

-- Run migrations
print("Running migrations...")
carga.Migration.migrate()

-- === MODEL DEFINITIONS WITH ASSOCIATIONS ===
print("\n🏗️  2. MODELS WITH ASSOCIATIONS")

-- Company model
local Company = carga.Model:extend("Company")
Company.table_name = "companies"
Company:has_many("users")

-- User model with validations and associations
local User = carga.Model:extend("User")
User.table_name = "users"
User:belongs_to("company")
User:has_many("posts")

User.validations = {
    name = { required = true, min_length = 2 },
    email = { format = "email", unique = true },
    age = { type = "number", min = 0, max = 150 }
}

function User:validate()
    if self.age and self.age < 13 then
        self:add_error("age", "must be at least 13 years old")
    end
end

function User:before_save()
    if self.email then
        self.email = string.lower(self.email)
    end
end

-- Post model
local Post = carga.Model:extend("Post")
Post.table_name = "posts"
Post:belongs_to("user")

-- === BULK DATA CREATION ===
print("\n📦 3. BULK OPERATIONS")

-- Create companies
local companies_data = {
    { name = "Foguete Corp", industry = "Technology" },
    { name = "Rocket Industries", industry = "Aerospace" },
    { name = "Web Solutions", industry = "Technology" }
}

local companies = Company:create_all(companies_data)
print("Created " .. #companies .. " companies")

-- Create users with bulk insert
local users_data = {
    { name = "Alice Johnson", email = "ALICE@FOGUETE.COM", age = 28, company_id = 1 },
    { name = "Bob Smith", email = "BOB@ROCKET.COM", age = 35, company_id = 2 },
    { name = "Charlie Brown", email = "CHARLIE@WEB.COM", age = 22, company_id = 3 },
    { name = "Diana Prince", email = "DIANA@FOGUETE.COM", age = 30, company_id = 1 },
    { name = "Eve Wilson", email = "EVE@ROCKET.COM", age = 25, company_id = 2 }
}

local users = User:create_all(users_data)
print("Created " .. #users .. " users (emails auto-lowercased)")

-- Create posts
local posts_data = {
    { title = "Getting Started with Lua", content = "Lua is awesome!", user_id = 1, published = true },
    { title = "Web Development Tips", content = "Here are some tips...", user_id = 1, published = true },
    { title = "Rocket Science 101", content = "It's not that hard!", user_id = 2, published = true },
    { title = "Draft Post", content = "Work in progress...", user_id = 2, published = false },
    { title = "Charlie's Thoughts", content = "Random thoughts...", user_id = 3, published = true }
}

Post:insert_all(posts_data)
print("Created " .. #posts_data .. " posts")

-- === ADVANCED QUERIES ===
print("\n🔍 4. ADVANCED QUERY FEATURES")

-- Complex WHERE clauses
local tech_users = User:inner_join("companies", "users.company_id = companies.id")
                      :where("companies.industry = ?", { "Technology" })
                      :where_between("users.age", 20, 35)
                      :select("users.*, companies.name as company_name")
                      :all()

print("Tech company users aged 20-35:")
for _, user in ipairs(tech_users) do
    print("  - " .. user.name .. " (" .. user.age .. ") at " .. user.company_name)
end

-- WHERE IN with subquery-like behavior
local published_post_authors = User:where_in("id", {1, 2, 3})
                                  :where_like("email", "%foguete.com")
                                  :all()

print("\nFoguete users who might have published posts:")
for _, user in ipairs(published_post_authors) do
    print("  - " .. user.name .. " (" .. user.email .. ")")
end

-- Aggregation with GROUP BY
local user_post_counts = User:inner_join("posts", "users.id = posts.user_id")
                            :select("users.name, COUNT(posts.id) as post_count")
                            :group("users.id, users.name")
                            :order("post_count DESC")
                            :all()

print("\nUsers by post count:")
for _, result in ipairs(user_post_counts) do
    print("  - " .. result.name .. ": " .. result.post_count .. " posts")
end

-- === ASSOCIATIONS & EAGER LOADING ===
print("\n🔗 5. ASSOCIATIONS & EAGER LOADING")

-- Demonstrate N+1 problem
print("Without eager loading (N+1 problem):")
local users_without_eager = User:limit(3):all()
for _, user in ipairs(users_without_eager) do
    local posts = user.posts:all()
    local company = user.company
    print("  - " .. user.name .. ": " .. #posts .. " posts, works at " .. (company and company.name or "Unknown"))
end

-- Solve N+1 with eager loading
print("\nWith eager loading (optimized):")
local users_with_eager = User:includes({"posts", "company"}):limit(3):all()
for _, user in ipairs(users_with_eager) do
    local posts = user.posts:all()
    local company = user.company
    print("  - " .. user.name .. ": " .. #posts .. " posts, works at " .. (company and company.name or "Unknown"))
end

-- Association creation
print("\nCreating post through association:")
local alice = User:find_by({ name = "Alice Johnson" })
local new_post = alice.posts:create({
    title = "Created via Association",
    content = "This post was created through the user.posts association",
    published = true
})
print("Created: " .. new_post.title .. " (ID: " .. new_post.id .. ")")

-- === VALIDATIONS ===
print("\n✅ 6. VALIDATIONS")

-- Valid user
local valid_user = User:new({
    name = "Frank Miller",
    email = "frank@example.com",
    age = 40,
    company_id = 1
})

if valid_user:valid() then
    print("✅ Valid user passed validation")
else
    print("❌ Valid user failed validation")
end

-- Invalid user
local invalid_user = User:new({
    name = "X",  -- Too short
    email = "not-an-email",  -- Invalid format
    age = 10,  -- Too young (custom validation)
    company_id = 1
})

if invalid_user:valid() then
    print("❌ Invalid user passed validation")
else
    print("✅ Invalid user failed validation as expected:")
    for field, errors in pairs(invalid_user:get_errors()) do
        for _, error in ipairs(errors) do
            print("    " .. field .. ": " .. error)
        end
    end
end

-- === TRANSACTIONS ===
print("\n💳 7. TRANSACTIONS")

-- Successful transaction
local initial_user_count = User:count()
carga.transaction(function()
    User:create({ name = "Transaction User 1", email = "trans1@example.com", age = 25, company_id = 1 })
    User:create({ name = "Transaction User 2", email = "trans2@example.com", age = 30, company_id = 2 })
end)
print("Users after successful transaction: " .. User:count() .. " (was " .. initial_user_count .. ")")

-- Failed transaction (rollback)
local before_failed = User:count()
local success, error_msg = pcall(function()
    carga.transaction(function()
        User:create({ name = "Will be rolled back", email = "rollback@example.com", age = 25, company_id = 1 })
        error("Intentional error to trigger rollback")
    end)
end)
print("Users after failed transaction: " .. User:count() .. " (still " .. before_failed .. ")")

-- === PERFORMANCE SHOWCASE ===
print("\n⚡ 8. PERFORMANCE")

-- Bulk operations vs individual
local start_time = os.clock()
for i = 1, 100 do
    Post:create({ title = "Individual " .. i, content = "Content", user_id = 1, published = false })
end
local individual_time = os.clock() - start_time

-- Clean up for bulk test
Post:where("title LIKE ?", { "Individual%" }):destroy_all()

start_time = os.clock()
local bulk_posts = {}
for i = 1, 100 do
    table.insert(bulk_posts, { title = "Bulk " .. i, content = "Content", user_id = 1, published = false })
end
Post:insert_all(bulk_posts)
local bulk_time = os.clock() - start_time

print("100 individual inserts: " .. string.format("%.3f", individual_time) .. "s")
print("100 bulk insert: " .. string.format("%.3f", bulk_time) .. "s")
print("Bulk is " .. string.format("%.1f", individual_time / bulk_time) .. "x faster!")

-- === FINAL STATISTICS ===
print("\n📊 9. FINAL STATISTICS")

local total_users = User:count()
local total_companies = Company:count()
local total_posts = Post:count()
local published_posts = Post:where({ published = true }):count()

print("Total users: " .. total_users)
print("Total companies: " .. total_companies)
print("Total posts: " .. total_posts)
print("Published posts: " .. published_posts)

-- Company with most users
local company_stats = Company:inner_join("users", "companies.id = users.company_id")
                            :select("companies.name, COUNT(users.id) as user_count")
                            :group("companies.id, companies.name")
                            :order("user_count DESC")
                            :first()

if company_stats then
    print("Largest company: " .. company_stats.name .. " (" .. company_stats.user_count .. " users)")
end

-- === CLEANUP ===
print("\n🧹 10. CLEANUP")

-- Reset migrations (drops all tables)
carga.Migration.reset()
print("All tables dropped via migration reset")

-- Cleanup files
carga.disconnect()
os.remove("showcase.sqlite3")
os.execute("rm -rf showcase_migrations")

print("\n🎉 Carga ORM Showcase Complete!")
print("\n✨ Features Demonstrated:")
print("   ✅ Migrations with up/down")
print("   ✅ Model inheritance and associations")
print("   ✅ Validations and callbacks")
print("   ✅ Bulk operations")
print("   ✅ Advanced query builder")
print("   ✅ Eager loading (N+1 prevention)")
print("   ✅ Transactions")
print("   ✅ Performance optimizations")
print("\n🚀 Ready for production use!")