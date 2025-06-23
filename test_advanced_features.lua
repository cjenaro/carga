#!/usr/bin/env lua

local carga = require("carga")

-- Setup test database
carga.configure({
    database_path = "test_advanced.sqlite3",
    enable_logging = true
})
carga.connect()

-- Create tables
carga.Database.create_table("users", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    name = "TEXT NOT NULL",
    email = "TEXT UNIQUE",
    age = "INTEGER",
    status = "TEXT DEFAULT 'active'"
})

carga.Database.create_table("posts", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    title = "TEXT NOT NULL",
    content = "TEXT",
    user_id = "INTEGER",
    published = "BOOLEAN DEFAULT 0"
})

-- Define models
local User = carga.Model:extend("User")
User.table_name = "users"

local Post = carga.Model:extend("Post")
Post.table_name = "posts"

print("🧪 Testing Advanced Features")
print("=" .. string.rep("=", 40))

-- Test 1: Bulk insert
print("\n📦 Testing bulk insert...")

local users_data = {
    { name = "Alice Johnson", email = "alice@example.com", age = 28, status = "active" },
    { name = "Bob Smith", email = "bob@example.com", age = 35, status = "active" },
    { name = "Charlie Brown", email = "charlie@example.com", age = 22, status = "inactive" },
    { name = "Diana Prince", email = "diana@example.com", age = 30, status = "active" },
    { name = "Eve Wilson", email = "eve@example.com", age = 25, status = "pending" }
}

local bulk_result = User:insert_all(users_data)
print("Bulk insert result:")
print("  Success:", bulk_result.success)
print("  Inserted count:", bulk_result.inserted_count)
print("  First ID:", bulk_result.first_id)
print("  Last ID:", bulk_result.last_id)

-- Test 2: Create all (with instances)
local posts_data = {
    { title = "First Post", content = "Hello World", user_id = 1, published = true },
    { title = "Second Post", content = "Another post", user_id = 1, published = false },
    { title = "Third Post", content = "Bob's post", user_id = 2, published = true },
    { title = "Fourth Post", content = "Charlie's post", user_id = 3, published = true },
    { title = "Fifth Post", content = "Diana's post", user_id = 4, published = false }
}

local post_instances = Post:create_all(posts_data)
print("\nCreated " .. #post_instances .. " post instances")

-- Test 3: Advanced WHERE clauses
print("\n🔍 Testing advanced WHERE clauses...")

-- WHERE IN
local active_users = User:where_in("status", {"active", "pending"}):all()
print("Active/pending users:", #active_users)

-- WHERE NOT IN
local non_inactive_users = User:where_not_in("status", {"inactive"}):all()
print("Non-inactive users:", #non_inactive_users)

-- WHERE BETWEEN
local middle_aged_users = User:where_between("age", 25, 30):all()
print("Users aged 25-30:", #middle_aged_users)

-- WHERE LIKE
local users_with_a = User:where_like("name", "%a%"):all()
print("Users with 'a' in name:", #users_with_a)

-- WHERE NULL/NOT NULL
local users_with_age = User:where_not_null("age"):all()
print("Users with age specified:", #users_with_age)

-- Test 4: Complex queries
print("\n🔗 Testing complex queries...")

-- Multiple conditions
local complex_users = User:where({ status = "active" })
                         :where_between("age", 20, 35)
                         :where_like("email", "%example.com")
                         :order("age")
                         :all()
print("Complex query users:", #complex_users)
for _, user in ipairs(complex_users) do
    print("  - " .. user.name .. " (" .. user.age .. ")")
end

-- Test 5: DISTINCT queries
print("\n🎯 Testing DISTINCT queries...")

local distinct_statuses = User:select("status"):distinct():all()
print("Distinct statuses:")
for _, result in ipairs(distinct_statuses) do
    print("  - " .. (result.status or "nil"))
end

-- Test 6: JOIN queries
print("\n🔗 Testing JOIN queries...")

local users_with_posts = User:inner_join("posts", "users.id = posts.user_id")
                            :select("users.name, COUNT(posts.id) as post_count")
                            :group("users.id, users.name")
                            :all()

print("Users with posts:")
for _, result in ipairs(users_with_posts) do
    print("  - " .. result.name .. ": " .. result.post_count .. " posts")
end

-- Test 7: Subquery-like behavior with WHERE IN
print("\n📊 Testing subquery-like behavior...")

-- Get IDs of users who have published posts
local published_post_user_ids = {}
local published_posts = Post:where({ published = true }):all()
for _, post in ipairs(published_posts) do
    published_post_user_ids[post.user_id] = true
end

local user_ids_array = {}
for user_id in pairs(published_post_user_ids) do
    table.insert(user_ids_array, user_id)
end

local users_with_published_posts = User:where_in("id", user_ids_array):all()
print("Users with published posts:", #users_with_published_posts)
for _, user in ipairs(users_with_published_posts) do
    print("  - " .. user.name)
end

-- Test 8: Aggregation queries
print("\n📈 Testing aggregation queries...")

local user_count = User:count()
local active_user_count = User:where({ status = "active" }):count()
local avg_age_result = User:select("AVG(age) as avg_age"):first()

print("Total users:", user_count)
print("Active users:", active_user_count)
print("Average age:", avg_age_result and avg_age_result.avg_age or "N/A")

-- Test 9: Pagination
print("\n📄 Testing pagination...")

local page1_users = User:order("name"):limit(2):all()
local page2_users = User:order("name"):limit(2):offset(2):all()

print("Page 1 users:")
for _, user in ipairs(page1_users) do
    print("  - " .. user.name)
end

print("Page 2 users:")
for _, user in ipairs(page2_users) do
    print("  - " .. user.name)
end

-- Test 10: Performance comparison
print("\n⚡ Testing performance...")

local start_time = os.clock()
for i = 1, 100 do
    User:where({ status = "active" }):count()
end
local single_query_time = os.clock() - start_time

print("100 individual queries took: " .. string.format("%.3f", single_query_time) .. " seconds")

-- Cleanup
print("\n🧹 Cleaning up...")
carga.disconnect()
os.remove("test_advanced.sqlite3")

print("\n✅ Advanced features tests completed!")