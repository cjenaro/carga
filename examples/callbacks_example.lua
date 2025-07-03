-- Example: Model with Callbacks and Custom Validation
local carga = require("carga")

-- Configure and connect
carga.configure({ database_path = "examples/callbacks.db" })
carga.connect()

---@class User : Model
---@field id number
---@field name string
---@field email string
---@field password_hash string
---@field created_at string
---@field updated_at string
local User = carga.Model:extend("User", "users")

-- Schema definition
User.schema = {
    id = { type = "integer", primary_key = true, auto_increment = true },
    name = { type = "text" },
    email = { type = "text" },
    password_hash = { type = "text" },
    created_at = { type = "datetime" },
    updated_at = { type = "datetime" }
}

-- Validations
User.validations = {
    name = { required = true, type = "string" },
    email = { required = true, type = "string" },
    password_hash = { required = true, type = "string" }
}

-- Custom validation method
---@return nil
function User:validate()
    local email = self:get_attribute("email")
    if email and not email:match("^[%w._%+-]+@[%w._%+-]+%.%w+$") then
        self:add_error("email", "must be a valid email address")
    end
    
    local name = self:get_attribute("name")
    if name and #name < 2 then
        self:add_error("name", "must be at least 2 characters long")
    end
    
    -- Example of forbidden values
    if name == "admin" or name == "root" then
        self:add_error("name", "is reserved and cannot be used")
    end
end

-- Before save callback - called before any save operation
---@return nil
function User:before_save()
    print("🔄 Before save callback triggered for user: " .. (self:get_attribute("name") or "unknown"))
    
    -- Normalize email to lowercase
    local email = self:get_attribute("email")
    if email then
        self:set_attribute("email", email:lower())
    end
    
    -- Set updated_at timestamp
    self:set_attribute("updated_at", os.date("%Y-%m-%d %H:%M:%S"))
end

-- Before create callback - called only for new records
---@return nil
function User:before_create()
    print("✨ Before create callback triggered - setting created_at timestamp")
    self:set_attribute("created_at", os.date("%Y-%m-%d %H:%M:%S"))
end

-- Before update callback - called only for existing records
---@return nil
function User:before_update()
    print("📝 Before update callback triggered for existing user")
    -- Could add logic like incrementing version numbers, etc.
end

-- Before destroy callback
---@return nil
function User:before_destroy()
    print("🗑️  Before destroy callback triggered - cleaning up user data")
    -- Could add cleanup logic here
end

-- After save callback - called after successful save
---@return nil
function User:after_save()
    print("✅ After save callback - user successfully saved with ID: " .. self:get_attribute("id"))
end

-- After create callback - called after successful create
---@return nil
function User:after_create()
    print("🎉 After create callback - new user created!")
end

-- After update callback - called after successful update
---@return nil
function User:after_update()
    print("📋 After update callback - user data updated!")
end

-- After destroy callback - called after successful destroy
---@return nil
function User:after_destroy()
    print("💀 After destroy callback - user has been removed")
end

-- Demonstration function
local function demonstrate_callbacks()
    print("=== Carga Model Callbacks Example ===\n")
    
    -- Test 1: Create a valid user (triggers before_save, before_create, after_save, after_create)
    print("1. Creating a valid user...")
    local user = User:new({
        name = "John Doe",
        email = "JOHN.DOE@EXAMPLE.COM",  -- Will be normalized to lowercase
        password_hash = "hashed_password_123"
    })
    
    if user:save() then
        print("✅ User created successfully!\n")
    else
        print("❌ Failed to create user")
        local errors = user:get_errors()
        for field, field_errors in pairs(errors) do
            for _, error_msg in ipairs(field_errors) do
                print("  " .. field .. ": " .. error_msg)
            end
        end
    end
    
    -- Test 2: Try to create an invalid user (validation should fail)
    print("2. Attempting to create invalid user...")
    local invalid_user = User:new({
        name = "admin",  -- Reserved name
        email = "invalid-email",  -- Invalid email format
        password_hash = "password"
    })
    
    if invalid_user:save() then
        print("✅ User created")
    else
        print("❌ Validation failed (as expected):")
        local errors = invalid_user:get_errors()
        for field, field_errors in pairs(errors) do
            for _, error_msg in ipairs(field_errors) do
                print("  " .. field .. ": " .. error_msg)
            end
        end
        print()
    end
    
    -- Test 3: Update existing user (triggers before_save, before_update, after_save, after_update)
    print("3. Updating existing user...")
    if user:update({ name = "John Smith" }) then
        print("✅ User updated successfully!\n")
    end
    
    -- Test 4: Destroy user (triggers before_destroy, after_destroy)
    print("4. Destroying user...")
    if user:destroy() then
        print("✅ User destroyed successfully!\n")
    end
    
    print("=== Callbacks demonstration completed ===")
end

-- Run the demonstration
demonstrate_callbacks()

-- Clean up
carga.disconnect()

return User