# Carga - Active Record ORM 📦

Carga is a production-ready SQLite-based Active Record ORM that brings Rails-like database patterns to Lua. Built for the Foguete framework, Carga provides a comprehensive, high-performance database abstraction layer with zero-config setup.

## Features

- **🏗️ Active Record Pattern** - Models that encapsulate data and behavior with inheritance
- **💾 SQLite Integration** - Optimized SQLite database with WAL mode and performance tuning
- **🔗 Associations** - belongs_to, has_many, has_one relationships with eager loading
- **🔍 Query Builder** - Chainable query interface with prepared statements
- **📊 Migrations** - Schema versioning and database evolution tools  
- **✅ Validations** - Comprehensive data integrity and validation rules
- **🔄 Callbacks** - Lifecycle hooks for model events
- **⚡ Performance** - Bulk operations, N+1 prevention, connection pooling
- **🔒 Security** - SQL injection protection with parameter binding

## Installation

Add to your rockspec dependencies:

```lua
dependencies = {
   "carga >= 0.0.1"
}
```

Or install directly:
```bash
luarocks install carga
```

## Quick Start

```lua
local carga = require("carga")

-- Connect to database
carga.Database.connect("db/app.sqlite3")

-- Define a model
local User = carga.Model:extend("User")
User.table_name = "users"

-- Create records
local user = User:create({
    name = "John Doe",
    email = "john@example.com"
})

-- Query records
local users = User:where({ active = true })
                 :order("created_at DESC")
                 :limit(10)
                 :all()
```

## Database Connection

```lua
-- Connect to database
carga.Database.connect("db/development.sqlite3")

-- Execute raw SQL
carga.Database.execute("CREATE TABLE users (...)")

-- Query with parameters
local results = carga.Database.query("SELECT * FROM users WHERE active = ?", { true })
```

## Model Definition

```lua
local User = carga.Model:extend("User")

-- Table configuration
User.table_name = "users"
User.primary_key = "id"

-- Field definitions
User.fields = {
    id = { type = "integer", primary_key = true },
    name = { type = "text", required = true },
    email = { type = "text", unique = true },
    age = { type = "integer", min = 0, max = 150 },
    active = { type = "boolean", default = true },
    created_at = { type = "datetime", default = "now" },
    updated_at = { type = "datetime", default = "now" }
}

-- Custom validation
function User:validate()
    if not self.name or #self.name < 2 then
        self:add_error("name", "must be at least 2 characters")
    end
    
    if not self.email or not self.email:match("@") then
        self:add_error("email", "must be a valid email address")
    end
    
    if self.age and self.age < 13 then
        self:add_error("age", "must be at least 13 years old")
    end
end

-- Callbacks
function User:before_save()
    self.updated_at = os.date("!%Y-%m-%d %H:%M:%S")
    if self.email then
        self.email = self.email:lower()
    end
end

function User:after_create()
    print("Welcome, " .. self.name .. "!")
end

return User
```

## CRUD Operations

### Create
```lua
-- Create and save immediately
local user = User:create({
    name = "Jane Smith",
    email = "jane@example.com",
    age = 25
})

-- Build instance and save later
local user = User:new({ name = "Bob" })
user.email = "bob@example.com"
user:save()

-- Multiple creates (individual transactions)
User:create({ name = "Alice", email = "alice@example.com" })
User:create({ name = "Charlie", email = "charlie@example.com" })
User:create({ name = "Diana", email = "diana@example.com" })
```

### Read
```lua
-- Find by primary key
local user = User:find(1)

-- Find first matching record
local user = User:find_by({ email = "john@example.com" })

-- Get all records
local users = User:all()

-- Complex queries
local active_users = User:where({ active = true })
                        :order("created_at DESC")
                        :limit(10)
                        :all()

-- Count records
local count = User:count()

-- Check existence
local user = User:find_by({ email = "test@example.com" })
local exists = user ~= nil
```

### Update
```lua
-- Update instance
local user = User:find(1)
user.name = "Updated Name"
user:save()

-- Update with hash
user:update({ name = "New Name", age = 30 })

-- Individual updates for multiple records
local users = User:where({ active = false }):all()
for _, user in ipairs(users) do
    user:update({ active = true })
end
```

### Delete
```lua
-- Delete instance
local user = User:find(1)
user:destroy()

-- Delete multiple records individually
local inactive_users = User:where({ active = false }):all()
for _, user in ipairs(inactive_users) do
    user:destroy()
end
```

## Query Builder

Build complex queries with a chainable interface:

```lua
-- Basic queries
User:where({ active = true })
    :order("created_at DESC")
    :limit(20)
    :offset(40)
    :all()

-- Count records
User:count()

-- First and last
User:order("created_at DESC"):first()
User:order("created_at ASC"):first()  -- equivalent to last
```

## Associations

Define and use relationships between models:

```lua
-- Define associations
local User = carga.Model:extend("User")
User.has_many = { "posts", "comments" }
User.belongs_to = { "company" }

local Post = carga.Model:extend("Post")  
Post.belongs_to = { "user" }
Post.has_many = { "comments" }

local Comment = carga.Model:extend("Comment")
Comment.belongs_to = { "user", "post" }

-- Use associations
local user = User:find(1)

-- Access associations (lazy loaded)
local posts = user:posts():where({ published = true }):all()
local company = user:company()

-- Eager loading (prevents N+1 queries)
local users = User:includes({ "posts", "company" })
                 :where({ active = true })
                 :all()

-- Each user now has preloaded posts and company
for _, user in ipairs(users) do
    if user.company then
        print(user.name .. " works at " .. user.company.name)
    end
    if user.posts then
        print("Has " .. #user.posts .. " posts")
    end
end
```

## Migrations

Create and manage database schema changes:

```lua
-- Manual table creation
carga.Database.execute([[
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        age INTEGER,
        active BOOLEAN DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
]])

-- Add indexes
carga.Database.execute("CREATE UNIQUE INDEX idx_users_email ON users(email)")
carga.Database.execute("CREATE INDEX idx_users_active ON users(active)")
```

## Validations

### Custom Validations

```lua
function User:validate()
    -- Presence validation
    if not self.name or #self.name == 0 then
        self:add_error("name", "is required")
    end
    
    -- Length validation
    if self.name and (#self.name < 2 or #self.name > 50) then
        self:add_error("name", "must be between 2 and 50 characters")
    end
    
    -- Format validation
    if self.email and not self.email:match("@") then
        self:add_error("email", "must be a valid email address")
    end
    
    -- Numeric validation
    if self.age and (type(self.age) ~= "number" or self.age < 0 or self.age > 150) then
        self:add_error("age", "must be a number between 0 and 150")
    end
    
    -- Inclusion validation
    local valid_statuses = { "active", "inactive", "pending" }
    if self.status then
        local valid = false
        for _, status in ipairs(valid_statuses) do
            if self.status == status then
                valid = true
                break
            end
        end
        if not valid then
            self:add_error("status", "must be active, inactive, or pending")
        end
    end
end
```

### Custom Validations

```lua
function User:validate()
    -- Custom email domain validation
    if self.email and not self.email:match("@company%.com$") then
        self:add_error("email", "must be a company email address")
    end
    
    -- Cross-field validation
    if self.age and self.age < 18 and self.role == "admin" then
        self:add_error("role", "admins must be at least 18 years old")
    end
end

-- Check validation
local user = User:new({ name = "John", email = "invalid" })
if user:valid() then
    user:save()
else
    local errors = user:get_errors()
    for field, messages in pairs(errors) do
        print(field .. ": " .. table.concat(messages, ", "))
    end
end
```

## Callbacks

Hook into model lifecycle events:

```lua
-- Save callbacks
function User:before_save()
    self.updated_at = os.date("!%Y-%m-%d %H:%M:%S")
    if self.email then
        self.email = self.email:lower()
    end
end

function User:after_save()
    -- Clear cache, send notifications, etc.
    self:clear_cached_data()
end

-- Create callbacks  
function User:before_create()
    self.created_at = os.date("!%Y-%m-%d %H:%M:%S")
end

function User:after_create()
    -- Send welcome email, create profile, etc.
    EmailService:send_welcome(self)
    self:create_default_profile()
end

-- Update callbacks
function User:before_update()
    -- Log changes, validate business rules, etc.
    self:log_changes()
end

-- Destroy callbacks
function User:before_destroy()
    -- Cleanup dependent records
    self:posts():destroy_all()
end

function User:after_destroy()
    -- Clean up files, clear caches, etc.
    FileService:cleanup_user_files(self.id)
end
```

## Manual Transactions

Handle database transactions manually:

```lua
-- Manual transaction control
local db = carga.Database.get_connection()
db:exec("BEGIN")

local success, err = pcall(function()
    -- Your database operations here
    local user = User:create({ name = "Jane", email = "jane@example.com" })
    local post = Post:create({ title = "Hello", user_id = user.id })
end)

if success then
    db:exec("COMMIT")
    print("Transaction completed successfully")
else
    db:exec("ROLLBACK")
    print("Transaction rolled back: " .. tostring(err))
end
```

## Raw SQL

When you need raw SQL access:

```lua
-- Raw queries
local results = carga.Database.query("SELECT * FROM users WHERE name LIKE ?", { "%john%" })

-- Execute raw SQL
carga.Database.execute("UPDATE users SET active = ? WHERE last_login < ?", { 
    false, 
    "2023-01-01" 
})

-- Access raw results
for _, row in ipairs(results.rows) do
    print(row.name, row.email)
end
```

## Performance Features

### Individual Operations

```lua
-- Individual creates (each in separate transaction)
User:create({ name = "Alice", email = "alice@example.com" })
User:create({ name = "Bob", email = "bob@example.com" })
User:create({ name = "Carol", email = "carol@example.com" })

-- Individual updates
local inactive_users = User:where({ active = false }):all()
for _, user in ipairs(inactive_users) do
    user:update({ active = true })
end

-- Individual deletes
local users_to_delete = User:where({ last_login = nil }):all()
for _, user in ipairs(users_to_delete) do
    user:destroy()
end
```

### N+1 Query Prevention

```lua
-- Without eager loading (N+1 problem)
local users = User:all()
for _, user in ipairs(users) do
    local posts = user:posts():all()  -- Separate query for each user
end

-- With eager loading (optimized queries)
local users = User:includes("posts"):all()
for _, user in ipairs(users) do
    if user.posts then
        print("User " .. user.name .. " has " .. #user.posts .. " posts")
    end
end

-- Multiple associations
local users = User:includes({ "posts", "company" }):all()
```

## Error Handling

```lua
-- Validation errors
local user = User:new({ email = "invalid" })
if not user:save() then
    local errors = user:get_errors()
    for field, messages in pairs(errors) do
        print("Error in " .. field .. ": " .. table.concat(messages, ", "))
    end
end

-- Database errors
local success, err = pcall(function()
    User:create({ name = "John" })  -- Might fail due to constraints
end)

if not success then
    print("Database error: " .. err)
end
```

## Advanced Features

### Model Introspection

```lua
-- Get model information
print(User.table_name)      -- "users"
print(User.primary_key)     -- "id" 
print(User.class_name)      -- "User"

-- Check associations
local associations = User:get_associations()
for name, association in pairs(associations) do
    print("Association: " .. name .. " (" .. association.type .. ")")
end
```

### Connection Management

```lua
-- Connect to database
carga.Database.connect("path/to/database.sqlite3")

-- Get current connection
local db = carga.Database.get_connection()

-- Disconnect when done
carga.Database.disconnect()
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure all tests pass
5. Submit a pull request

## Testing

Run the test suite:

```bash
busted spec/
```

All tests should pass with 100% coverage.

## License

MIT License - see LICENSE file for details.

## About

Carga is part of the [Foguete](https://github.com/foguete) ecosystem, a modern web framework for Lua. Built with performance, developer experience, and Rails familiarity in mind.

**Key Design Principles:**
- **Zero Configuration** - Works out of the box with sensible defaults
- **Rails Compatibility** - Familiar API for Rails developers  
- **Performance First** - Optimized for speed and memory efficiency
- **SQLite Focused** - Deep integration with SQLite's unique features
- **Production Ready** - Battle-tested with comprehensive error handling
