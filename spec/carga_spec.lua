-- Comprehensive test suite for Carga ORM
local carga = require("carga")

-- Test database setup
local test_db_path = "spec/test.sqlite3"

-- Clean up function
local function cleanup()
    os.remove(test_db_path)
end

-- Setup test database
local function setup()
    cleanup()
    carga.configure({
        database_path = test_db_path,
        enable_logging = false
    })
    carga.connect()
    
    -- Create test table
    carga.Database.create_table("users", {
        id = "INTEGER PRIMARY KEY AUTOINCREMENT",
        name = "TEXT NOT NULL",
        email = "TEXT UNIQUE",
        age = "INTEGER",
        active = "BOOLEAN DEFAULT 1",
        created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
    })
end

-- Test User model
local User = carga.Model:extend("User")
User.table_name = "users"
User.validations = {
    name = { required = true, min_length = 2 },
    email = { format = "email", unique = true },
    age = { type = "number", min = 0, max = 150 }
}

function User:validate()
    if self.name and self.name == "invalid" then
        self:add_error("name", "cannot be 'invalid'")
    end
end

function User:before_save()
    if self.email then
        self.email = string.lower(self.email)
    end
end

-- Test suite
local tests = {}
local test_count = 0
local passed_count = 0

local function test(name, func)
    test_count = test_count + 1
    print("🧪 " .. name)
    
    local success, error_msg = pcall(func)
    if success then
        passed_count = passed_count + 1
        print("  ✅ PASSED")
    else
        print("  ❌ FAILED: " .. tostring(error_msg))
    end
    print()
end

local function assert_equal(expected, actual, message)
    if expected ~= actual then
        error((message or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "Expected true, got false")
    end
end

local function assert_false(value, message)
    if value then
        error(message or "Expected false, got true")
    end
end

local function assert_nil(value, message)
    if value ~= nil then
        error(message or "Expected nil, got " .. tostring(value))
    end
end

local function assert_not_nil(value, message)
    if value == nil then
        error(message or "Expected non-nil value")
    end
end

-- Run tests
print("🚀 Starting Carga ORM Test Suite")
print("=" .. string.rep("=", 50))

setup()

-- Database connection tests
test("Database connection", function()
    local db = carga.Database.get_connection()
    assert_not_nil(db, "Database connection should exist")
    assert_true(carga.Database.table_exists("users"), "Users table should exist")
end)

-- Model creation tests
test("Model class creation", function()
    assert_equal("User", User.class_name)
    assert_equal("users", User.table_name)
    assert_not_nil(User.validations)
end)

test("Model instance creation", function()
    local user = User:new({ name = "John", email = "john@example.com", age = 30 })
    assert_equal("John", user.name)
    assert_equal("john@example.com", user.email)
    assert_equal(30, user.age)
    assert_false(user._persisted)
end)

-- CRUD operation tests
test("Create and save user", function()
    local user = User:new({ name = "Alice", email = "alice@example.com", age = 25 })
    assert_true(user:save(), "User should save successfully")
    assert_true(user._persisted, "User should be marked as persisted")
    assert_not_nil(user.id, "User should have an ID after saving")
end)

test("Find user by ID", function()
    local user = User:create({ name = "Bob", email = "bob@example.com", age = 35 })
    local found_user = User:find(user.id)
    assert_not_nil(found_user, "Should find user by ID")
    assert_equal("Bob", found_user.name)
    assert_equal("bob@example.com", found_user.email)
end)

test("Find user by conditions", function()
    User:create({ name = "Charlie", email = "charlie@example.com", age = 40 })
    local found_user = User:find_by({ name = "Charlie" })
    assert_not_nil(found_user, "Should find user by name")
    assert_equal("charlie@example.com", found_user.email)
end)

test("Update user", function()
    local user = User:create({ name = "David", email = "david@example.com", age = 28 })
    user.age = 29
    assert_true(user:save(), "User update should save successfully")
    
    local updated_user = User:find(user.id)
    assert_equal(29, updated_user.age, "Age should be updated")
end)

test("Delete user", function()
    local user = User:create({ name = "Eve", email = "eve@example.com", age = 32 })
    local user_id = user.id
    assert_true(user:destroy(), "User should be deleted successfully")
    
    local deleted_user = User:find(user_id)
    assert_nil(deleted_user, "User should not be found after deletion")
end)

-- Query builder tests
test("Where clause", function()
    User:create({ name = "Frank", email = "frank@example.com", age = 45 })
    User:create({ name = "Grace", email = "grace@example.com", age = 22 })
    
    local young_users = User:where("age < ?", { 30 }):all()
    assert_true(#young_users >= 1, "Should find young users")
    
    local frank = User:where({ name = "Frank" }):first()
    assert_not_nil(frank, "Should find Frank")
    assert_equal(45, frank.age)
end)

test("Order and limit", function()
    User:create({ name = "Henry", email = "henry@example.com", age = 50 })
    User:create({ name = "Ivy", email = "ivy@example.com", age = 18 })
    
    local oldest_user = User:order("age", "DESC"):first()
    assert_not_nil(oldest_user, "Should find oldest user")
    
    local limited_users = User:limit(2):all()
    assert_true(#limited_users <= 2, "Should limit results")
end)

test("Count", function()
    local initial_count = User:count()
    User:create({ name = "Jack", email = "jack@example.com", age = 33 })
    local new_count = User:count()
    assert_equal(initial_count + 1, new_count, "Count should increase by 1")
end)

-- Validation tests
test("Required validation", function()
    local user = User:new({ email = "test@example.com" })
    assert_false(user:valid(), "User without name should be invalid")
    assert_true(user:has_errors(), "User should have errors")
    assert_not_nil(user._errors.name, "Should have name error")
end)

test("Email format validation", function()
    local user = User:new({ name = "Test", email = "invalid-email" })
    assert_false(user:valid(), "User with invalid email should be invalid")
    assert_not_nil(user._errors.email, "Should have email error")
end)

test("Custom validation", function()
    local user = User:new({ name = "invalid", email = "test@example.com" })
    assert_false(user:valid(), "User with name 'invalid' should be invalid")
    assert_not_nil(user._errors.name, "Should have custom name error")
end)

test("Length validation", function()
    local user = User:new({ name = "A", email = "a@example.com" })
    assert_false(user:valid(), "User with short name should be invalid")
    assert_not_nil(user._errors.name, "Should have name length error")
end)

-- Callback tests
test("Before save callback", function()
    local user = User:new({ name = "Test", email = "TEST@EXAMPLE.COM" })
    user:save()
    assert_equal("test@example.com", user.email, "Email should be lowercased by callback")
end)

-- Transaction tests
test("Transaction rollback", function()
    local initial_count = User:count()
    
    local success, error_msg = pcall(function()
        carga.transaction(function()
            User:create({ name = "Transaction Test", email = "trans@example.com" })
            error("Intentional error to trigger rollback")
        end)
    end)
    
    assert_false(success, "Transaction should fail")
    assert_equal(initial_count, User:count(), "Count should be unchanged after rollback")
end)

test("Transaction commit", function()
    local initial_count = User:count()
    
    carga.transaction(function()
        User:create({ name = "Transaction Success", email = "success@example.com" })
    end)
    
    assert_equal(initial_count + 1, User:count(), "Count should increase after successful transaction")
end)

-- Cleanup
cleanup()

-- Results
print("=" .. string.rep("=", 50))
print("🏁 Test Results: " .. passed_count .. "/" .. test_count .. " passed")

if passed_count == test_count then
    print("🎉 All tests passed!")
    os.exit(0)
else
    print("💥 Some tests failed!")
    os.exit(1)
end