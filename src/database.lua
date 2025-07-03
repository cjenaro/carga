-- Database connection and query management
local sqlite3 = require("lsqlite3")

---@class Database
local Database = {}

-- Configuration
local config = {
	database_path = "db/development.sqlite3",
	connection_pool_size = 5,
	query_timeout = 30000,
	enable_logging = false,
	log_slow_queries = true,
	slow_query_threshold = 1000,
}

-- Connection pool
local connection_pool = {}
local active_connections = {}
local current_connection = nil

-- Configure database
---@param opts table Configuration options
---@return nil
function Database.configure(opts)
	for k, v in pairs(opts) do
		config[k] = v
	end
end

-- Get configuration
---@return table config Current configuration
function Database.get_config()
	return config
end

-- Connect to database
---@param database_path string? Path to database file
---@return boolean success Connection success
function Database.connect(database_path)
	database_path = database_path or config.database_path

	print("🔗 Attempting to connect to database: " .. database_path)

	-- Ensure directory exists
	local dir = database_path:match("(.+)/[^/]+$")
	if dir then
		os.execute("mkdir -p " .. dir)
	end

	-- Check if database file exists
	local file = io.open(database_path, "r")
	if file then
		file:close()
		print("✅ Database file exists: " .. database_path)
	else
		print("⚠️  Database file does not exist, will be created: " .. database_path)
	end

	local db, err = sqlite3.open(database_path)
	if not db then
		print("❌ Failed to connect to database: " .. database_path)
		print("❌ Error: " .. tostring(err))
		error("Failed to connect to database: " .. tostring(err))
	end

	-- Test the connection
	local test_result = db:exec("SELECT 1")
	if test_result ~= sqlite3.OK then
		print("❌ Database connection test failed")
		db:close()
		error("Database connection test failed")
	end

	-- Configure SQLite for better performance
	db:exec("PRAGMA journal_mode = WAL")
	db:exec("PRAGMA synchronous = NORMAL")
	db:exec("PRAGMA cache_size = 10000")
	db:exec("PRAGMA foreign_keys = ON")
	db:exec("PRAGMA temp_store = MEMORY")

	current_connection = db
	table.insert(active_connections, db)

	print("✅ Successfully connected to database: " .. database_path)

	return db
end

-- Get current connection (create if needed)
---@return userdata? connection SQLite connection object or nil
function Database.get_connection()
	if not current_connection then
		print("⚠️  No database connection found, attempting to connect...")
		print("🔍 Using database path: " .. config.database_path)
		Database.connect()
	end

	-- Verify connection is still valid
	if current_connection then
		local test_result = current_connection:exec("SELECT 1")
		if test_result ~= sqlite3.OK then
			print("❌ Database connection is invalid, reconnecting...")
			current_connection = nil
			Database.connect()
		end
	end

	if not current_connection then
		error("❌ Failed to establish database connection to: " .. config.database_path)
	end

	return current_connection
end

-- Close all connections
---@return boolean success True if disconnection succeeded
function Database.disconnect()
	for _, db in ipairs(active_connections) do
		if db then
			db:close()
		end
	end
	active_connections = {}
	current_connection = nil

	if config.enable_logging then
		print("🔌 Disconnected from database")
	end

	return true
end

-- Execute SQL statement (INSERT, UPDATE, DELETE)
---@param sql string SQL query
---@param params any[]? Query parameters
---@return table result Query result
function Database.execute(sql, params)
	local db = Database.get_connection()
	params = params or {}

	local start_time = os.clock()

	if config.enable_logging then
		print("🔍 SQL: " .. sql)
		if #params > 0 then
			local param_strings = {}
			for i, param in ipairs(params) do
				table.insert(param_strings, tostring(param))
			end
			print("📊 Params: " .. table.concat(param_strings, ", "))
		end
	end

	local stmt = db:prepare(sql)
	if not stmt then
		-- Always log the failing SQL query for debugging
		print("❌ SQL Error: " .. db:errmsg())
		print("🔍 Failed SQL: " .. sql)
		if #params > 0 then
			print("📊 Params: " .. table.concat(params, ", "))
		end
		error("Failed to prepare statement: " .. db:errmsg())
	end

	-- Bind parameters
	for i, param in ipairs(params) do
		stmt:bind(i, param)
	end

	local result = stmt:step()
	local affected_rows = db:changes()
	local last_insert_id = db:last_insert_rowid()

	stmt:finalize()

	local execution_time = (os.clock() - start_time) * 1000

	if config.log_slow_queries and execution_time > config.slow_query_threshold then
		print("🐌 Slow query (" .. string.format("%.2f", execution_time) .. "ms): " .. sql)
	end

	return {
		success = result == sqlite3.DONE,
		affected_rows = affected_rows,
		last_insert_id = last_insert_id,
		execution_time = execution_time,
	}
end

-- Query SQL statement (SELECT)
---@param sql string SQL query
---@param params any[]? Query parameters
---@return table[] rows Query result rows
function Database.query(sql, params)
	local db = Database.get_connection()
	params = params or {}

	local start_time = os.clock()

	if config.enable_logging then
		print("🔍 SQL: " .. sql)
		if #params > 0 then
			print("📊 Params: " .. table.concat(params, ", "))
		end
	end

	local stmt = db:prepare(sql)
	if not stmt then
		-- Always log the failing SQL query for debugging
		print("❌ SQL Error: " .. db:errmsg())
		print("🔍 Failed SQL: " .. sql)
		if #params > 0 then
			print("📊 Params: " .. table.concat(params, ", "))
		end
		error("Failed to prepare statement: " .. db:errmsg())
	end

	-- Bind parameters
	for i, param in ipairs(params) do
		stmt:bind(i, param)
	end

	local results = {}
	local columns = {}

	-- Get column names on first row
	local first_row = true

	while stmt:step() == sqlite3.ROW do
		if first_row then
			for i = 0, stmt:columns() - 1 do
				table.insert(columns, stmt:get_name(i))
			end
			first_row = false
		end

		local row = {}
		for i = 0, stmt:columns() - 1 do
			local column_name = columns[i + 1]
			row[column_name] = stmt:get_value(i)
		end
		table.insert(results, row)
	end

	stmt:finalize()

	local execution_time = (os.clock() - start_time) * 1000

	if config.log_slow_queries and execution_time > config.slow_query_threshold then
		print("🐌 Slow query (" .. string.format("%.2f", execution_time) .. "ms): " .. sql)
	end

	return {
		rows = results,
		count = #results,
		columns = columns,
		execution_time = execution_time,
	}
end

-- Transaction support
---@param callback function Transaction callback function
---@return any result Callback return value
function Database.transaction(callback)
	local db = Database.get_connection()

	db:exec("BEGIN TRANSACTION")

	local success, result = pcall(callback)

	if success then
		db:exec("COMMIT")
		return result
	else
		db:exec("ROLLBACK")
		error("Transaction failed: " .. tostring(result))
	end
end

-- Check if table exists
---@param table_name string Table name to check
---@return boolean exists True if table exists
function Database.table_exists(table_name)
	local result = Database.query("SELECT name FROM sqlite_master WHERE type='table' AND name=?", { table_name })
	return result.count > 0
end

-- Get table schema
---@param table_name string Table name
---@return table[] schema Table schema information
function Database.get_table_schema(table_name)
	local result = Database.query("PRAGMA table_info(" .. table_name .. ")")
	return result.rows
end

-- Create table
---@param table_name string Table name
---@param columns table[] Column definitions
---@return table result Operation result
function Database.create_table(table_name, columns)
	local column_defs = {}
	for name, definition in pairs(columns) do
		table.insert(column_defs, name .. " " .. definition)
	end

	local sql = "CREATE TABLE " .. table_name .. " (" .. table.concat(column_defs, ", ") .. ")"
	return Database.execute(sql)
end

-- Drop table
---@param table_name string Table name to drop
---@return table result Operation result
function Database.drop_table(table_name)
	local sql = "DROP TABLE IF EXISTS " .. table_name
	return Database.execute(sql)
end

-- Add index
function Database.add_index(table_name, column_name, index_name)
	index_name = index_name or ("idx_" .. table_name .. "_" .. column_name)
	local sql = "CREATE INDEX " .. index_name .. " ON " .. table_name .. " (" .. column_name .. ")"
	return Database.execute(sql)
end

-- Remove index
function Database.remove_index(index_name)
	local sql = "DROP INDEX IF EXISTS " .. index_name
	return Database.execute(sql)
end

return Database
