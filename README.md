# Carga - Active Record ORM 📦

Carga is a SQLite-based Active Record ORM that brings Rails-like database patterns to Lua.

## Features

- **Active Record Pattern** - Models that encapsulate data and behavior
- **SQLite Integration** - Optimized for SQLite database
- **Relationship Support** - belongs_to, has_many, has_one associations
- **Query Builder** - Chainable query interface
- **Migrations** - Schema versioning and evolution
- **Validations** - Data integrity and validation rules
- **Callbacks** - Hooks for model lifecycle events

## Quick Start

```lua
local carga = require("foguete.carga")

-- Define a model
local User = carga.Model:extend("User")
User.table_name = "users"

-- Create records
local user = User:create({
    name = "John Doe",
    email = "john@example.com"
})

-- Find records
local user = User:find(1)
local users = User:where({ active = true }):all()
```

## Model Definition

```lua
local User = carga.Model:extend("User")

User.table_name = "users"
User.fields = {
    id = { type = "integer", primary_key = true },
    name = { type = "text", required = true },
    email = { type = "text", unique = true },
    age = { type = "integer", min = 0, max = 150 },
    created_at = { type = "datetime", default = "now" },
    updated_at = { type = "datetime", default = "now" }
}

-- Validations
function User:validate()
    if not self.email or not self.email:match("@") then
        self:add_error("email", "must be a valid email address")
    end
    
    if not self.name or #self.name < 2 then
        self:add_error("name", "must be at least 2 characters")
    end
end

-- Callbacks
function User:before_save()
    self.updated_at = os.date("!%Y-%m-%d %H:%M:%S")
end

return User
```

## CRUD Operations

### Create
```lua
-- Create and save
local user = User:create({
    name = "Jane Smith",
    email = "jane@example.com"
})

-- Build and save later
local user = User:new({ name = "Bob" })
user.email = "bob@example.com"
user:save()
```

### Read
```lua
-- Find by ID
local user = User:find(1)

-- Find by conditions
local user = User:find_by({ email = "john@example.com" })

-- Get all records
local users = User:all()

-- Query with conditions
local active_users = User:where({ active = true }):all()
```

### Update
```lua
local user = User:find(1)
user.name = "Updated Name"
user:save()

-- Or update directly
User:find(1):update({ name = "Updated Name" })
```

### Delete
```lua
local user = User:find(1)
user:destroy()

-- Or delete by conditions
User:where({ active = false }):destroy_all()
```

## Query Builder

Chain methods to build complex queries:

```lua
User:where({ active = true })
    :where("age > ?", { 18 })
    :order("created_at DESC")
    :limit(10)
    :offset(20)
    :all()

-- Joins
User:joins("posts")
    :where("posts.published = ?", { true })
    :select("users.*, COUNT(posts.id) as post_count")
    :group("users.id")
    :all()
```

## Relationships

Define associations between models:

```lua
-- User model
User.has_many = { "posts", "comments" }
User.belongs_to = { "company" }

-- Post model
Post.belongs_to = { "user" }
Post.has_many = { "comments" }

-- Usage
local user = User:find(1)
local posts = user:posts():where({ published = true }):all()
local company = user:company()
```

## Migrations

Create and manage database schema:

```lua
-- db/migrate/001_create_users.lua
return {
    up = function(db)
        db:create_table("users", {
            id = "integer primary key autoincrement",
            name = "text not null",
            email = "text unique not null",
            active = "boolean default true",
            created_at = "datetime default current_timestamp",
            updated_at = "datetime default current_timestamp"
        })
        
        db:add_index("users", "email")
    end,
    
    down = function(db)
        db:drop_table("users")
    end
}
```

Run migrations:
```bash
fog migrate          # Run pending migrations
fog migrate:rollback # Rollback last migration
fog migrate:status   # Show migration status
```

## Validations

Built-in validation rules:

```lua
User.validations = {
    name = { required = true, min_length = 2, max_length = 50 },
    email = { required = true, format = "email", unique = true },
    age = { type = "integer", min = 0, max = 150 },
    status = { inclusion = { "active", "inactive", "pending" } }
}
```

Custom validations:
```lua
function User:validate()
    if self.age and self.age < 13 then
        self:add_error("age", "must be at least 13 years old")
    end
end
```

## Callbacks

Hook into model lifecycle:

```lua
function User:before_save()
    self.email = self.email:lower()
end

function User:after_create()
    -- Send welcome email
    EmailService:send_welcome(self)
end

function User:before_destroy()
    -- Clean up associated data
    self:posts():destroy_all()
end
```

## Raw SQL

When you need raw SQL:

```lua
-- Raw queries
local results = User:query("SELECT * FROM users WHERE name LIKE ?", { "%john%" })

-- Execute raw SQL
User:execute("UPDATE users SET active = ? WHERE last_login < ?", { false, "2023-01-01" })
```

## Contributing

Follow Carga conventions:
- Use prepared statements for security
- Support both sync and async operations
- Maintain SQLite compatibility
- Include comprehensive validations
- Write thorough tests
