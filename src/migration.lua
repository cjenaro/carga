-- Migration system for Carga ORM
local Database = require("carga.src.database")

local Migration = {}

-- Migration configuration
local config = {
    migrations_path = "db/migrate",
    schema_table = "schema_migrations"
}

-- Configure migration system
function Migration.configure(opts)
    for k, v in pairs(opts) do
        config[k] = v
    end
end

-- Get configuration
function Migration.get_config()
    return config
end

-- Ensure schema migrations table exists
function Migration.ensure_schema_table()
    if not Database.table_exists(config.schema_table) then
        Database.create_table(config.schema_table, {
            version = "TEXT PRIMARY KEY",
            migrated_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        })
    end
end

-- Get migrated versions
function Migration.get_migrated_versions()
    Migration.ensure_schema_table()
    local result = Database.query("SELECT version FROM " .. config.schema_table .. " ORDER BY version")
    local versions = {}
    for _, row in ipairs(result.rows) do
        table.insert(versions, row.version)
    end
    return versions
end

-- Check if version is migrated
function Migration.is_migrated(version)
    Migration.ensure_schema_table()
    local result = Database.query(
        "SELECT COUNT(*) as count FROM " .. config.schema_table .. " WHERE version = ?",
        { version }
    )
    return result.rows[1].count > 0
end

-- Record migration
function Migration.record_migration(version)
    Database.execute(
        "INSERT INTO " .. config.schema_table .. " (version) VALUES (?)",
        { version }
    )
end

-- Remove migration record
function Migration.remove_migration_record(version)
    Database.execute(
        "DELETE FROM " .. config.schema_table .. " WHERE version = ?",
        { version }
    )
end

-- Get pending migrations
function Migration.get_pending_migrations()
    local migrated = Migration.get_migrated_versions()
    local migrated_set = {}
    for _, version in ipairs(migrated) do
        migrated_set[version] = true
    end
    
    local all_migrations = Migration.get_all_migrations()
    local pending = {}
    
    for _, migration in ipairs(all_migrations) do
        if not migrated_set[migration.version] then
            table.insert(pending, migration)
        end
    end
    
    return pending
end

-- Get all migration files
function Migration.get_all_migrations()
    local migrations = {}
    
    -- Create migrations directory if it doesn't exist
    os.execute("mkdir -p " .. config.migrations_path)
    
    -- List migration files
    local handle = io.popen("ls " .. config.migrations_path .. "/*.lua 2>/dev/null")
    if handle then
        for filename in handle:lines() do
            local basename = filename:match("([^/]+)%.lua$")
            if basename then
                local version = basename:match("^(%d+)")
                if version then
                    table.insert(migrations, {
                        version = version,
                        filename = filename,
                        basename = basename
                    })
                end
            end
        end
        handle:close()
    end
    
    -- Sort by version
    table.sort(migrations, function(a, b)
        return tonumber(a.version) < tonumber(b.version)
    end)
    
    return migrations
end

-- Load migration file
function Migration.load_migration(filename)
    local migration = dofile(filename)
    if type(migration) ~= "table" then
        error("Migration file must return a table: " .. filename)
    end
    if type(migration.up) ~= "function" then
        error("Migration must have an 'up' function: " .. filename)
    end
    if type(migration.down) ~= "function" then
        error("Migration must have a 'down' function: " .. filename)
    end
    return migration
end

-- Run a single migration up
function Migration.migrate_up(migration_info)
    print("🔼 Migrating up: " .. migration_info.basename)
    
    local migration = Migration.load_migration(migration_info.filename)
    local migrator = MigrationDSL.new()
    
    Database.transaction(function()
        migration.up(migrator)
        Migration.record_migration(migration_info.version)
    end)
    
    print("✅ Migrated: " .. migration_info.basename)
end

-- Run a single migration down
function Migration.migrate_down(migration_info)
    print("🔽 Rolling back: " .. migration_info.basename)
    
    local migration = Migration.load_migration(migration_info.filename)
    local migrator = MigrationDSL.new()
    
    Database.transaction(function()
        migration.down(migrator)
        Migration.remove_migration_record(migration_info.version)
    end)
    
    print("✅ Rolled back: " .. migration_info.basename)
end

-- Run all pending migrations
function Migration.migrate()
    local pending = Migration.get_pending_migrations()
    
    if #pending == 0 then
        print("📋 No pending migrations")
        return
    end
    
    print("🚀 Running " .. #pending .. " pending migrations...")
    
    for _, migration_info in ipairs(pending) do
        Migration.migrate_up(migration_info)
    end
    
    print("🎉 All migrations completed!")
end

-- Rollback last migration
function Migration.rollback()
    local migrated = Migration.get_migrated_versions()
    
    if #migrated == 0 then
        print("📋 No migrations to rollback")
        return
    end
    
    local last_version = migrated[#migrated]
    local all_migrations = Migration.get_all_migrations()
    
    local migration_info = nil
    for _, info in ipairs(all_migrations) do
        if info.version == last_version then
            migration_info = info
            break
        end
    end
    
    if not migration_info then
        error("Migration file not found for version: " .. last_version)
    end
    
    Migration.migrate_down(migration_info)
end

-- Show migration status
function Migration.status()
    local all_migrations = Migration.get_all_migrations()
    local migrated = Migration.get_migrated_versions()
    local migrated_set = {}
    for _, version in ipairs(migrated) do
        migrated_set[version] = true
    end
    
    print("📊 Migration Status:")
    print("=" .. string.rep("=", 50))
    
    if #all_migrations == 0 then
        print("No migration files found")
        return
    end
    
    for _, migration_info in ipairs(all_migrations) do
        local status = migrated_set[migration_info.version] and "✅ up" or "⏳ down"
        print(string.format("%-20s %s", migration_info.version, status) .. " " .. migration_info.basename)
    end
end

-- Reset all migrations (dangerous!)
function Migration.reset()
    print("⚠️  Resetting all migrations...")
    
    local migrated = Migration.get_migrated_versions()
    local all_migrations = Migration.get_all_migrations()
    
    -- Rollback all migrations in reverse order
    for i = #migrated, 1, -1 do
        local version = migrated[i]
        local migration_info = nil
        for _, info in ipairs(all_migrations) do
            if info.version == version then
                migration_info = info
                break
            end
        end
        
        if migration_info then
            Migration.migrate_down(migration_info)
        end
    end
    
    print("🔄 All migrations reset!")
end

-- Generate migration file
function Migration.generate(name)
    -- Add microseconds to ensure unique timestamps
    local timestamp = os.date("%Y%m%d%H%M%S")
    local microseconds = string.format("%06d", math.random(0, 999999))
    local filename = timestamp .. microseconds .. "_" .. name:lower():gsub("%s+", "_") .. ".lua"
    local filepath = config.migrations_path .. "/" .. filename
    
    -- Ensure directory exists
    os.execute("mkdir -p " .. config.migrations_path)
    
    local template = [[-- Migration: ]] .. name .. [[

return {
    up = function(db)
        -- Add your migration code here
        -- Example:
        -- db:create_table("users", {
        --     id = "INTEGER PRIMARY KEY AUTOINCREMENT",
        --     name = "TEXT NOT NULL",
        --     email = "TEXT UNIQUE",
        --     created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        -- })
        -- 
        -- db:add_index("users", "email")
    end,
    
    down = function(db)
        -- Add your rollback code here
        -- Example:
        -- db:drop_table("users")
    end
}
]]
    
    local file = io.open(filepath, "w")
    if not file then
        error("Could not create migration file: " .. filepath)
    end
    
    file:write(template)
    file:close()
    
    print("📝 Generated migration: " .. filename)
    return filepath
end

-- Migration DSL for database operations
local MigrationDSL = {}
MigrationDSL.__index = MigrationDSL

function MigrationDSL.new()
    return setmetatable({}, MigrationDSL)
end

-- Create table
function MigrationDSL:create_table(table_name, columns)
    return Database.create_table(table_name, columns)
end

-- Drop table
function MigrationDSL:drop_table(table_name)
    return Database.drop_table(table_name)
end

-- Add column
function MigrationDSL:add_column(table_name, column_name, column_type)
    local sql = "ALTER TABLE " .. table_name .. " ADD COLUMN " .. column_name .. " " .. column_type
    return Database.execute(sql)
end

-- Drop column (SQLite limitation - requires table recreation)
function MigrationDSL:drop_column(table_name, column_name)
    -- Get current schema
    local schema = Database.get_table_schema(table_name)
    local new_columns = {}
    
    for _, column_info in ipairs(schema) do
        if column_info.name ~= column_name then
            table.insert(new_columns, column_info.name .. " " .. column_info.type)
        end
    end
    
    if #new_columns == #schema then
        error("Column not found: " .. column_name)
    end
    
    -- Create temporary table
    local temp_table = table_name .. "_temp"
    local sql = "CREATE TABLE " .. temp_table .. " (" .. table.concat(new_columns, ", ") .. ")"
    Database.execute(sql)
    
    -- Copy data
    local column_names = {}
    for _, column_info in ipairs(schema) do
        if column_info.name ~= column_name then
            table.insert(column_names, column_info.name)
        end
    end
    
    local copy_sql = "INSERT INTO " .. temp_table .. " SELECT " .. 
                     table.concat(column_names, ", ") .. " FROM " .. table_name
    Database.execute(copy_sql)
    
    -- Drop original table and rename temp
    Database.execute("DROP TABLE " .. table_name)
    Database.execute("ALTER TABLE " .. temp_table .. " RENAME TO " .. table_name)
    
    return { success = true }
end

-- Rename table
function MigrationDSL:rename_table(old_name, new_name)
    local sql = "ALTER TABLE " .. old_name .. " RENAME TO " .. new_name
    return Database.execute(sql)
end

-- Rename column
function MigrationDSL:rename_column(table_name, old_name, new_name)
    local sql = "ALTER TABLE " .. table_name .. " RENAME COLUMN " .. old_name .. " TO " .. new_name
    return Database.execute(sql)
end

-- Add index
function MigrationDSL:add_index(table_name, column_name, index_name)
    return Database.add_index(table_name, column_name, index_name)
end

-- Remove index
function MigrationDSL:remove_index(index_name)
    return Database.remove_index(index_name)
end

-- Execute raw SQL
function MigrationDSL:execute(sql, params)
    return Database.execute(sql, params)
end

-- Export
Migration.MigrationDSL = MigrationDSL

return Migration