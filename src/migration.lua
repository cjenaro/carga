-- Migration system for Carga ORM
local Database = require("carga.src.database")

---@class Migration
local Migration = {}

-- Forward declaration of MigrationDSL
local MigrationDSL

-- Migration configuration
local config = {
	migrations_path = "db/migrate",
	schema_table = "schema_migrations",
}

-- Configure migration system
---@param opts table Configuration options
---@return nil
function Migration.configure(opts)
	for k, v in pairs(opts) do
		config[k] = v
	end
end

-- Get configuration
---@return table config Current migration configuration
function Migration.get_config()
	return config
end

-- Ensure schema migrations table exists
---@return nil
function Migration.ensure_schema_table()
	if not Database.table_exists(config.schema_table) then
		Database.create_table(config.schema_table, {
			version = "TEXT PRIMARY KEY",
			migrated_at = "DATETIME DEFAULT CURRENT_TIMESTAMP",
		})
	end
end

-- Get migrated versions
---@return string[] versions List of migrated version numbers
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
---@param version string Migration version to check
---@return boolean migrated True if migration has been applied
function Migration.is_migrated(version)
	Migration.ensure_schema_table()
	local result =
		Database.query("SELECT COUNT(*) as count FROM " .. config.schema_table .. " WHERE version = ?", { version })
	return result.rows[1].count > 0
end

-- Record migration
---@param version string Migration version to record
---@return boolean success True if recording succeeded
function Migration.record_migration(version)
	Database.execute("INSERT INTO " .. config.schema_table .. " (version) VALUES (?)", { version })
end

-- Remove migration record
---@param version string Migration version to remove
---@return boolean success True if removal succeeded
function Migration.remove_migration_record(version)
	Database.execute("DELETE FROM " .. config.schema_table .. " WHERE version = ?", { version })
end

-- Get pending migrations
---@return table[] migrations List of pending migration files
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
---@return table[] migrations List of all migration files
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
						basename = basename,
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
---@param filename string Migration file name
---@return table? migration Loaded migration module or nil
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
		-- Set up the package path to find models
		local original_path = package.path
		local demo_path = "./demo/?.lua;./demo/app/?.lua;./demo/app/models/?.lua;"
		package.path = demo_path .. package.path

		local success, err = pcall(function()
			migration.up(migrator)
		end)

		-- Restore original path
		package.path = original_path

		if not success then
			error("Migration failed: " .. tostring(err))
		end

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
		-- Set up the package path to find models
		local original_path = package.path
		local demo_path = "./demo/?.lua;./demo/app/?.lua;./demo/app/models/?.lua;"
		package.path = demo_path .. package.path

		local success, err = pcall(function()
			migration.down(migrator)
		end)

		-- Restore original path
		package.path = original_path

		if not success then
			error("Rollback failed: " .. tostring(err))
		end

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

	local template = [[-- Migration: ]]
		.. name
		.. [[

return {
    up = function(db)
        -- Add your migration code here
        
        -- Traditional SQL approach:
        -- db:create_table("users", {
        --     id = "INTEGER PRIMARY KEY AUTOINCREMENT",
        --     name = "TEXT NOT NULL",
        --     email = "TEXT UNIQUE",
        --     created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
        -- })
        -- db:add_index("users", "email")
        
        -- Model-based approach (recommended):
        -- local User = db:model("User")
        -- db:remove_field_from_model(User, "description")
        -- db:add_field_to_model(User, "bio", "TEXT", { default = "" })
        -- db:rename_field_in_model(User, "old_name", "new_name")
        -- db:create_table_from_model(User)
    end,
    
    down = function(db)
        -- Add your rollback code here
        
        -- Traditional SQL approach:
        -- db:drop_table("users")
        
        -- Model-based approach (recommended):
        -- local User = db:model("User")
        -- db:add_field_to_model(User, "description", "TEXT")
        -- db:remove_field_from_model(User, "bio")
        -- db:rename_field_in_model(User, "new_name", "old_name")
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
---@class MigrationDSL
MigrationDSL = {}
MigrationDSL.__index = MigrationDSL

---@return MigrationDSL dsl New migration DSL instance
function MigrationDSL.new()
	local instance = setmetatable({}, MigrationDSL)
	instance._model_cache = {}
	return instance
end

-- Create table
---@param table_name string Name of table to create
---@param columns table[] Column definitions
---@return table result Operation result
function MigrationDSL:create_table(table_name, columns)
	return Database.create_table(table_name, columns)
end

-- Drop table
---@param table_name string Name of table to drop
---@return table result Operation result
function MigrationDSL:drop_table(table_name)
	return Database.drop_table(table_name)
end

-- Add column
---@param table_name string Table name
---@param column_name string Column name
---@param column_type string Column type
---@return table result Operation result
function MigrationDSL:add_column(table_name, column_name, column_type)
	local sql = "ALTER TABLE " .. table_name .. " ADD COLUMN " .. column_name .. " " .. column_type
	return Database.execute(sql)
end

-- Drop column (SQLite limitation - requires table recreation)
function MigrationDSL:drop_column(table_name, column_name)
	-- Get original CREATE TABLE statement
	local result = Database.query("SELECT sql FROM sqlite_master WHERE type='table' AND name='" .. table_name .. "'")
	if not result.rows or #result.rows == 0 then
		error("Table not found: " .. table_name)
	end

	local original_sql = result.rows[1].sql

	-- Parse the CREATE TABLE statement to remove the column
	-- This is a simplified parser - for production, you'd want a more robust one
	local create_part, columns_part = original_sql:match("^(CREATE TABLE [^(]+)%((.+)%)$")
	if not create_part or not columns_part then
		error("Could not parse CREATE TABLE statement for: " .. table_name)
	end

	-- Split columns and filter out the one to drop
	local columns = {}
	local current_column = ""
	local paren_depth = 0

	for char in columns_part:gmatch(".") do
		if char == "(" then
			paren_depth = paren_depth + 1
		elseif char == ")" then
			paren_depth = paren_depth - 1
		elseif char == "," and paren_depth == 0 then
			-- End of column definition
			local trimmed = current_column:match("^%s*(.-)%s*$")
			local col_name = trimmed:match("^([%w_]+)")
			if col_name ~= column_name then
				table.insert(columns, trimmed)
			end
			current_column = ""
		else
			current_column = current_column .. char
		end
	end

	-- Handle the last column
	if current_column ~= "" then
		local trimmed = current_column:match("^%s*(.-)%s*$")
		local col_name = trimmed:match("^([%w_]+)")
		if col_name ~= column_name then
			table.insert(columns, trimmed)
		end
	end

	if #columns == 0 then
		error("Cannot drop all columns from table")
	end

	-- Create temporary table with preserved schema
	local temp_table = table_name .. "_temp"
	local new_sql = create_part .. "(" .. table.concat(columns, ", ") .. ")"
	-- Handle both quoted and unquoted table names
	new_sql = new_sql:gsub('CREATE TABLE "?' .. table_name .. '"?', "CREATE TABLE " .. temp_table)

	Database.execute(new_sql)

	-- Copy data (extract column names from the new columns list)
	local column_names = {}
	for _, col_def in ipairs(columns) do
		-- Extract column name (handle underscores in names)
		local col_name = col_def:match("^([%w_]+)")
		if col_name then
			table.insert(column_names, col_name)
		end
	end

	local copy_sql = "INSERT INTO "
		.. temp_table
		.. " SELECT "
		.. table.concat(column_names, ", ")
		.. " FROM "
		.. table_name
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
---@param sql string SQL statement to execute
---@param params any[]? SQL parameters
---@return table result Operation result
function MigrationDSL:execute(sql, params)
	return Database.execute(sql, params)
end

-- Model-based migration methods

-- Load a model class for use in migrations
---@param model_name string Name of the model class (e.g., "User", "Movie")
---@return table model_class The loaded model class
function MigrationDSL:model(model_name)
	if self._model_cache[model_name] then
		return self._model_cache[model_name]
	end

	-- Try to load the model from common paths
	local model_paths = {
		"app.models." .. string.lower(model_name),
		"models." .. string.lower(model_name),
		string.lower(model_name),
	}

	for _, path in ipairs(model_paths) do
		local success, model_class = pcall(require, path)
		if success and model_class then
			self._model_cache[model_name] = model_class
			return model_class
		end
	end

	error("Could not load model: " .. model_name)
end

-- Remove a field from a model's schema and table
---@param model_class table The model class
---@param field_name string Name of the field to remove
---@return table result Operation result
function MigrationDSL:remove_field_from_model(model_class, field_name)
	local table_name = model_class.table_name
	if not table_name then
		error("Model does not have a table_name: " .. tostring(model_class.class_name))
	end

	print("🔧 Removing field '" .. field_name .. "' from " .. (model_class.class_name or "model"))

	-- Remove from database table
	local result = self:drop_column(table_name, field_name)

	-- Note: We don't modify the model file itself, that should be done manually
	-- This just handles the database schema change

	return result
end

-- Add a field to a model's table
---@param model_class table The model class
---@param field_name string Name of the field to add
---@param field_type string SQL type for the field
---@param options table? Additional options (default, null, etc.)
---@return table result Operation result
function MigrationDSL:add_field_to_model(model_class, field_name, field_type, options)
	local table_name = model_class.table_name
	if not table_name then
		error("Model does not have a table_name: " .. tostring(model_class.class_name))
	end

	options = options or {}
	local full_type = field_type

	-- Add constraints
	if options.not_null then
		full_type = full_type .. " NOT NULL"
	end
	if options.default then
		if type(options.default) == "string" then
			full_type = full_type .. " DEFAULT '" .. options.default .. "'"
		else
			full_type = full_type .. " DEFAULT " .. tostring(options.default)
		end
	end
	if options.unique then
		full_type = full_type .. " UNIQUE"
	end

	print("🔧 Adding field '" .. field_name .. "' to " .. (model_class.class_name or "model"))

	return self:add_column(table_name, field_name, full_type)
end

-- Rename a field in a model's table
---@param model_class table The model class
---@param old_name string Current field name
---@param new_name string New field name
---@return table result Operation result
function MigrationDSL:rename_field_in_model(model_class, old_name, new_name)
	local table_name = model_class.table_name
	if not table_name then
		error("Model does not have a table_name: " .. tostring(model_class.class_name))
	end

	print("🔧 Renaming field '" .. old_name .. "' to '" .. new_name .. "' in " .. (model_class.class_name or "model"))

	return self:rename_column(table_name, old_name, new_name)
end

-- Create a table based on a model's schema
---@param model_class table The model class
---@param options table? Additional options
---@return table result Operation result
function MigrationDSL:create_table_from_model(model_class, options)
	options = options or {}
	local table_name = model_class.table_name
	local schema = model_class.schema

	if not table_name then
		error("Model does not have a table_name: " .. tostring(model_class.class_name))
	end

	if not schema then
		error("Model does not have a schema: " .. tostring(model_class.class_name))
	end

	print("🔧 Creating table '" .. table_name .. "' from " .. (model_class.class_name or "model") .. " schema")

	-- Convert model schema to database columns
	local columns = {}
	for field_name, field_def in pairs(schema) do
		local column_def = self:_convert_model_field_to_sql(field_name, field_def)
		columns[field_name] = column_def
	end

	-- Add timestamps if not present and not disabled
	if not options.no_timestamps then
		if not columns.created_at then
			columns.created_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
		end
		if not columns.updated_at then
			columns.updated_at = "DATETIME DEFAULT CURRENT_TIMESTAMP"
		end
	end

	return self:create_table(table_name, columns)
end

-- Convert model field definition to SQL column definition
---@param field_name string Name of the field
---@param field_def table Field definition from model schema
---@return string sql_definition SQL column definition
function MigrationDSL:_convert_model_field_to_sql(field_name, field_def)
	local sql_type = field_def.type or "TEXT"

	-- Convert common types
	if sql_type == "integer" then
		sql_type = "INTEGER"
	elseif sql_type == "text" or sql_type == "string" then
		sql_type = "TEXT"
	elseif sql_type == "real" or sql_type == "float" then
		sql_type = "REAL"
	elseif sql_type == "boolean" then
		sql_type = "INTEGER" -- SQLite doesn't have native boolean
	end

	local definition = sql_type

	-- Add constraints
	if field_def.primary_key then
		definition = definition .. " PRIMARY KEY"
		if field_def.auto_increment then
			definition = definition .. " AUTOINCREMENT"
		end
	end

	if field_def.not_null and not field_def.primary_key then
		definition = definition .. " NOT NULL"
	end

	if field_def.unique and not field_def.primary_key then
		definition = definition .. " UNIQUE"
	end

	if field_def.default then
		if type(field_def.default) == "string" then
			definition = definition .. " DEFAULT '" .. field_def.default .. "'"
		else
			definition = definition .. " DEFAULT " .. tostring(field_def.default)
		end
	end

	return definition
end

-- Helper method to get model schema information
---@param model_class table The model class
---@return table schema_info Information about the model's schema
function MigrationDSL:get_model_schema_info(model_class)
	return {
		table_name = model_class.table_name,
		schema = model_class.schema,
		validations = model_class.validations,
		class_name = model_class.class_name,
	}
end

-- Export
Migration.MigrationDSL = MigrationDSL

return Migration
