#!/usr/bin/env lua

local carga = require("carga")

-- Setup test database
carga.configure({
    database_path = "test_associations.sqlite3",
    enable_logging = true
})
carga.connect()

-- Create tables
carga.Database.create_table("users", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    name = "TEXT NOT NULL",
    email = "TEXT UNIQUE",
    company_id = "INTEGER"
})

carga.Database.create_table("posts", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    title = "TEXT NOT NULL",
    content = "TEXT",
    user_id = "INTEGER NOT NULL"
})

carga.Database.create_table("companies", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    name = "TEXT NOT NULL"
})

carga.Database.create_table("profiles", {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    bio = "TEXT",
    user_id = "INTEGER UNIQUE"
})

-- Define models with associations
local User = carga.Model:extend("User")
User.table_name = "users"
User:belongs_to("company")
User:has_many("posts")
User:has_one("profile")

local Post = carga.Model:extend("Post")
Post.table_name = "posts"
Post:belongs_to("user")

local Company = carga.Model:extend("Company")
Company.table_name = "companies"
Company:has_many("users")

local Profile = carga.Model:extend("Profile")
Profile.table_name = "profiles"
Profile:belongs_to("user")

print("🧪 Testing Associations")
print("=" .. string.rep("=", 40))

-- Create test data
print("\n📝 Creating test data...")

local company = Company:create({ name = "Foguete Corp" })
print("Created company:", company.name)

local user1 = User:create({ 
    name = "Alice Johnson", 
    email = "alice@foguete.com",
    company_id = company.id
})
print("Created user:", user1.name)

local user2 = User:create({ 
    name = "Bob Smith", 
    email = "bob@foguete.com",
    company_id = company.id
})
print("Created user:", user2.name)

local post1 = Post:create({
    title = "First Post",
    content = "Hello World",
    user_id = user1.id
})
print("Created post:", post1.title)

local post2 = Post:create({
    title = "Second Post", 
    content = "Another post",
    user_id = user1.id
})
print("Created post:", post2.title)

local post3 = Post:create({
    title = "Bob's Post",
    content = "Bob's content",
    user_id = user2.id
})
print("Created post:", post3.title)

local profile = Profile:create({
    bio = "Software Engineer",
    user_id = user1.id
})
print("Created profile:", profile.bio)

-- Test belongs_to associations
print("\n🔗 Testing belongs_to associations...")

local loaded_user = User:find(user1.id)
local user_company = loaded_user.company
print("User's company:", user_company and user_company.name or "nil")

local loaded_post = Post:find(post1.id)
local post_author = loaded_post.user
print("Post author:", post_author and post_author.name or "nil")

-- Test has_many associations
print("\n📚 Testing has_many associations...")

local user_posts = loaded_user.posts:all()
print("User's posts count:", #user_posts)
for _, post in ipairs(user_posts) do
    print("  - " .. post.title)
end

local company_users = company.users:all()
print("Company users count:", #company_users)
for _, user in ipairs(company_users) do
    print("  - " .. user.name)
end

-- Test has_one associations
print("\n👤 Testing has_one associations...")

local user_profile = loaded_user.profile
print("User's profile:", user_profile and user_profile.bio or "nil")

-- Test association proxy methods
print("\n🔍 Testing association proxy methods...")

local user_post_count = loaded_user.posts:count()
print("User's post count (via proxy):", user_post_count)

local recent_posts = loaded_user.posts:where("title LIKE ?", { "%Post%" }):all()
print("User's posts with 'Post' in title:", #recent_posts)

-- Test association creation
print("\n➕ Testing association creation...")

local new_post = loaded_user.posts:create({
    title = "Created via association",
    content = "This post was created through the association"
})
print("Created post via association:", new_post.title)
print("Post's user_id:", new_post.user_id)

-- Test eager loading
print("\n⚡ Testing eager loading...")

print("Without eager loading (N+1 problem):")
local users_without_eager = User:all()
for _, user in ipairs(users_without_eager) do
    local posts = user.posts:all()
    print("  " .. user.name .. " has " .. #posts .. " posts")
end

print("\nWith eager loading (single query):")
local users_with_eager = User:includes("posts"):all()
for _, user in ipairs(users_with_eager) do
    local posts = user.posts:all()
    print("  " .. user.name .. " has " .. #posts .. " posts")
end

-- Test multiple includes
print("\n🔄 Testing multiple includes...")

local users_multi_include = User:includes({"posts", "company", "profile"}):all()
for _, user in ipairs(users_multi_include) do
    local posts = user.posts:all()
    local company_name = user.company and user.company.name or "No company"
    local profile_bio = user.profile and user.profile.bio or "No profile"
    print("  " .. user.name .. ": " .. #posts .. " posts, " .. company_name .. ", " .. profile_bio)
end

-- Cleanup
print("\n🧹 Cleaning up...")
carga.disconnect()
os.remove("test_associations.sqlite3")

print("\n✅ Association tests completed!")