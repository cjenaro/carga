-- Carga - Active Record ORM for Foguete
-- SQLite-based ORM with Rails-like patterns

---@class Carga
---@field VERSION string Package version
---@field Database Database Database operations
---@field Model Model Base model class
---@field QueryBuilder QueryBuilder Query builder class
---@field Migration Migration Migration operations
local carga = {}

-- Package version
carga.VERSION = "0.0.1"

-- Load core components
local Database = require("carga.src.database")
local Model = require("carga.src.model")
local QueryBuilder = require("carga.src.query_builder")
local Migration = require("carga.src.migration")

-- Export main components
carga.Database = Database
carga.Model = Model
carga.QueryBuilder = QueryBuilder
carga.Migration = Migration

-- Configuration
local config = {
    database_path = "db/development.sqlite3",
    connection_pool_size = 5,
    query_timeout = 30000, -- 30 seconds
    enable_logging = false,
    log_slow_queries = true,
    slow_query_threshold = 1000 -- 1 second
}

-- Configure carga
---@param opts table? Configuration options
---@return nil
function carga.configure(opts)
    opts = opts or {}
    for k, v in pairs(opts) do
        config[k] = v
    end
    
    -- Initialize database with new config
    Database.configure(config)
end

-- Get current configuration
---@return table config Current configuration
function carga.get_config()
    return config
end

-- Initialize database connection
---@param database_path string? Path to database file
---@return boolean success Connection success
function carga.connect(database_path)
    database_path = database_path or config.database_path
    return Database.connect(database_path)
end

-- Close database connections
function carga.disconnect()
    return Database.disconnect()
end

-- Execute raw SQL
---@param sql string SQL query
---@param params any[]? Query parameters
---@return table result Query result
function carga.execute(sql, params)
    return Database.execute(sql, params)
end

-- Query raw SQL
---@param sql string SQL query
---@param params any[]? Query parameters
---@return table[] rows Query result rows
function carga.query(sql, params)
    return Database.query(sql, params)
end

-- Transaction support
function carga.transaction(callback)
    return Database.transaction(callback)
end

return carga