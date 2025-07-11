-- Base Model class implementing Active Record pattern
local Database = require("carga.src.database")
local QueryBuilder = require("carga.src.query_builder")
local Associations = require("carga.src.associations")

---@class Model
---@field table_name string Database table name
---@field primary_key string Primary key field name (default: "id")
---@field schema table<string, table> Field schema definitions
---@field validations table<string, table> Validation rules
---@field has_many table<string, table> Has many associations
---@field belongs_to table<string, table> Belongs to associations
---@field has_one table<string, table> Has one associations
---@field class_name string Model class name
---@field validate function? Custom validation method
---@field before_save function? Called before save operations
---@field before_create function? Called before create operations
---@field before_update function? Called before update operations
---@field before_destroy function? Called before destroy operations
---@field after_save function? Called after save operations
---@field after_create function? Called after create operations
---@field after_update function? Called after update operations
---@field after_destroy function? Called after destroy operations
local Model = {}
Model.__index = Model

-- Class-level properties
Model.table_name = nil
Model.primary_key = "id"
Model.fields = {}
Model.validations = {}
Model.has_many = {}
Model.belongs_to = {}
Model.has_one = {}

--[[
Callback Methods (Optional - Define in your model class):

Custom Validation:
- validate() - Custom validation logic, called during valid()

Lifecycle Callbacks:
- before_save() - Called before any save operation
- before_create() - Called before creating new records
- before_update() - Called before updating existing records  
- before_destroy() - Called before destroying records
- after_save() - Called after successful save operations
- after_create() - Called after successful create operations
- after_update() - Called after successful update operations
- after_destroy() - Called after successful destroy operations

Example:
function MyModel:validate()
    if self:get_attribute("name") == "invalid" then
        self:add_error("name", "cannot be 'invalid'")
    end
end

function MyModel:before_save()
    self:set_attribute("updated_at", os.date("%Y-%m-%d %H:%M:%S"))
end
--]]

-- Create new model class
---@param class_name string Name of the model class
---@param table_name string? Database table name (optional)
---@return Model model_class New model class that inherits all Model methods
function Model:extend(class_name, table_name)
	local new_class = setmetatable({}, { __index = self })
	new_class.__index = new_class
	new_class.class_name = class_name

	-- Set table name - use provided table_name or default to pluralized class_name
	if table_name then
		new_class.table_name = table_name
	elseif not new_class.table_name then
		new_class.table_name = string.lower(class_name) .. "s"
	end

	-- Register the model class
	self:register_model(class_name, new_class)

	return new_class
end

-- Create new model instance
---@param attributes table? Initial attributes
---@return table instance New model instance
function Model:new(attributes)
	attributes = attributes or {}

	local instance = {
		_attributes = {},
		_errors = {},
		_persisted = false,
		_changed_attributes = {},
		_original_attributes = {},
		_model_class = self,
	}

	-- Set up metamethods for this instance
	local instance_mt = {
		__index = function(t, key)
			-- Check for attribute first
			if rawget(t, "_attributes") and rawget(t, "_attributes")[key] ~= nil then
				return rawget(t, "_attributes")[key]
			end

			-- Check for cached association
			local cached_key = "_" .. key
			if rawget(t, cached_key) ~= nil then
				return rawget(t, cached_key)
			end

			-- Check for association
			local association = Associations.get_association(self, key)
			if association then
				if association.type == Associations.BELONGS_TO then
					return t:get_belongs_to_association(key)
				elseif association.type == Associations.HAS_MANY then
					return t:get_has_many_association(key)
				elseif association.type == Associations.HAS_ONE then
					return t:get_has_one_association(key)
				end
			end

			-- Then check the class for methods
			return self[key]
		end,

		__newindex = function(t, key, value)
			if key:sub(1, 1) == "_" then
				-- Internal attributes
				rawset(t, key, value)
			else
				-- Model attributes
				if not rawget(t, "_attributes") then
					rawset(t, "_attributes", {})
				end
				local old_value = rawget(t, "_attributes")[key]
				rawget(t, "_attributes")[key] = value

				-- Track changes
				if rawget(t, "_persisted") and old_value ~= value then
					if not rawget(t, "_changed_attributes") then
						rawset(t, "_changed_attributes", {})
					end
					rawget(t, "_changed_attributes")[key] = { old_value, value }
				end
			end
		end,
	}

	setmetatable(instance, instance_mt)

	-- Set attributes
	for key, value in pairs(attributes) do
		instance:set_attribute(key, value)
	end

	-- Mark as clean if loaded from database
	if attributes[self.primary_key] then
		instance._persisted = true
		instance._original_attributes = {}
		for k, v in pairs(instance._attributes) do
			instance._original_attributes[k] = v
		end
	end

	return instance
end

-- Attribute accessors
---@param name string Attribute name
---@return any value Attribute value
function Model:get_attribute(name)
	return self._attributes[name]
end

---@param name string Attribute name
---@param value any Attribute value
---@return nil
function Model:set_attribute(name, value)
	if not self._attributes then
		self._attributes = {}
	end
	local old_value = self._attributes[name]
	self._attributes[name] = value

	-- Track changes
	if self._persisted and old_value ~= value then
		if not self._changed_attributes then
			self._changed_attributes = {}
		end
		self._changed_attributes[name] = { old_value, value }
	end
end

-- Validation methods
---@param field string Field name
---@param message string Error message
---@return nil
function Model:add_error(field, message)
	if not self._errors[field] then
		self._errors[field] = {}
	end
	table.insert(self._errors[field], message)
end

---@return nil
function Model:clear_errors()
	self._errors = {}
end

---@return boolean has_errors True if instance has validation errors
function Model:has_errors()
	for _ in pairs(self._errors) do
		return true
	end
	return false
end

---@return table<string, string[]> errors All validation errors
function Model:get_errors()
	return self._errors
end

---@return boolean valid True if instance passes all validations
function Model:valid()
	self:clear_errors()

	-- Run built-in validations
	self:run_validations()

	-- Run custom validation method
	if self.validate then
		self:validate()
	end

	return not self:has_errors()
end

---@return boolean invalid True if instance fails any validations
function Model:invalid()
	return not self:valid()
end

-- Built-in validation runner
---@return boolean success True if validations pass
function Model:run_validations()
	for field, rules in pairs(self.validations or {}) do
		local value = self:get_attribute(field)

		-- Required validation
		if rules.required and (value == nil or value == "") then
			self:add_error(field, "is required")
		end

		-- Type validation
		if value ~= nil and rules.type then
			if rules.type == "integer" and type(value) ~= "number" then
				self:add_error(field, "must be an integer")
			elseif rules.type == "string" and type(value) ~= "string" then
				self:add_error(field, "must be a string")
			end
		end

		-- Length validation
		if value and type(value) == "string" then
			if rules.min_length and #value < rules.min_length then
				self:add_error(field, "must be at least " .. rules.min_length .. " characters")
			end
			if rules.max_length and #value > rules.max_length then
				self:add_error(field, "must be no more than " .. rules.max_length .. " characters")
			end
		end

		-- Numeric validation
		if value and type(value) == "number" then
			if rules.min and value < rules.min then
				self:add_error(field, "must be at least " .. rules.min)
			end
			if rules.max and value > rules.max then
				self:add_error(field, "must be no more than " .. rules.max)
			end
		end

		-- Format validation
		if value and rules.format then
			if rules.format == "email" and not string.match(value, "^[%w._%+-]+@[%w.-]+%.[%a]+$") then
				self:add_error(field, "must be a valid email address")
			end
		end

		-- Inclusion validation
		if value and rules.inclusion then
			local found = false
			for _, allowed_value in ipairs(rules.inclusion) do
				if value == allowed_value then
					found = true
					break
				end
			end
			if not found then
				self:add_error(field, "must be one of: " .. table.concat(rules.inclusion, ", "))
			end
		end

		-- Uniqueness validation
		if value and rules.unique then
			local existing = self._model_class:where({ [field] = value }):first()
			if existing and existing:get_attribute(self.primary_key) ~= self:get_attribute(self.primary_key) then
				self:add_error(field, "must be unique")
			end
		end
	end
end

-- Persistence methods
---@return boolean success True if save succeeded
function Model:save()
	-- Run callbacks
	if self.before_save then
		self:before_save()
	end

	if not self._persisted and self.before_create then
		self:before_create()
	elseif self._persisted and self.before_update then
		self:before_update()
	end

	-- Validate
	if not self:valid() then
		return false
	end

	local success
	if self._persisted then
		success = self:update_record()
	else
		success = self:create_record()
	end

	if success then
		-- Run after callbacks
		if self.after_save then
			self:after_save()
		end

		if not self._persisted and self.after_create then
			self:after_create()
		elseif self._persisted and self.after_update then
			self:after_update()
		end

		self._persisted = true
		self._changed_attributes = {}

		-- Update original attributes
		self._original_attributes = {}
		for k, v in pairs(self._attributes) do
			self._original_attributes[k] = v
		end
	end

	return success
end

function Model:create_record()
	local columns = {}
	local placeholders = {}
	local values = {}

	for key, value in pairs(self._attributes) do
		-- Skip internal fields and primary key if nil
		if key ~= "_persisted" and (key ~= self.primary_key or value ~= nil) then
			table.insert(columns, key)
			table.insert(placeholders, "?")
			table.insert(values, value)
		end
	end

	local sql = "INSERT INTO "
		.. self.table_name
		.. " ("
		.. table.concat(columns, ", ")
		.. ") VALUES ("
		.. table.concat(placeholders, ", ")
		.. ")"

	local result = Database.execute(sql, values)

	if result.success then
		self._attributes[self.primary_key] = result.last_insert_id
		return true
	end

	return false
end

function Model:update_record()
	if not next(self._changed_attributes) then
		return true -- No changes to save
	end

	local set_clauses = {}
	local values = {}

	for key, _ in pairs(self._changed_attributes) do
		table.insert(set_clauses, key .. " = ?")
		table.insert(values, self._attributes[key])
	end

	table.insert(values, self:get_attribute(self.primary_key))

	local sql = "UPDATE "
		.. self.table_name
		.. " SET "
		.. table.concat(set_clauses, ", ")
		.. " WHERE "
		.. self.primary_key
		.. " = ?"

	local result = Database.execute(sql, values)
	return result.success
end

---@return boolean success True if destroy succeeded
function Model:destroy()
	if not self._persisted then
		return false
	end

	-- Run before_destroy callback
	if self.before_destroy then
		self:before_destroy()
	end

	local sql = "DELETE FROM " .. self.table_name .. " WHERE " .. self.primary_key .. " = ?"
	local result = Database.execute(sql, { self:get_attribute(self.primary_key) })

	if result.success then
		-- Run after_destroy callback
		if self.after_destroy then
			self:after_destroy()
		end

		self._persisted = false
		return true
	end

	return false
end

---@param attributes table<string, any> Attributes to update
---@return boolean success True if update succeeded
function Model:update(attributes)
	for key, value in pairs(attributes) do
		self:set_attribute(key, value)
	end
	return self:save()
end

-- Class methods for querying
---@param self Model Model class (use with : syntax)
---@return table[] instances All records
function Model:all()
	return QueryBuilder.new(self):all()
end

---@param self Model Model class (use with : syntax)
---@param conditions table|string WHERE conditions
---@param params any[]? Parameters for string conditions
---@return table[] instances Matching records
function Model:where(conditions, params)
	return QueryBuilder.new(self):where(conditions, params)
end

---@param self Model Model class (use with : syntax)
---@param id number|string Primary key value
---@return table? instance Found record or nil
function Model:find(id)
	return QueryBuilder.new(self):find(id)
end

---@param self Model Model class (use with : syntax)
---@param conditions table Find conditions
---@return table? instance First matching record or nil
function Model:find_by(conditions)
	return QueryBuilder.new(self):find_by(conditions)
end

---@param self Model Model class (use with : syntax)
---@return table? instance First record or nil
function Model:first()
	return QueryBuilder.new(self):first()
end

---@return table? instance Last record or nil
function Model:last()
	return QueryBuilder.new(self):last()
end

---@param self Model Model class (use with : syntax)
---@return number count Total record count
function Model:count()
	return QueryBuilder.new(self):count()
end

---@param column string Field to order by
---@param direction string? "ASC" or "DESC" (default: "ASC")
---@return table[] instances Ordered records
function Model:order(column, direction)
	return QueryBuilder.new(self):order(column, direction)
end

---@param count number Number of records to limit
---@return table[] instances Limited records
function Model:limit(count)
	return QueryBuilder.new(self):limit(count)
end

---@param count number Number of records to skip
---@return table[] instances Records with offset
function Model:offset(count)
	return QueryBuilder.new(self):offset(count)
end

function Model:select(columns)
	return QueryBuilder.new(self):select(columns)
end

function Model:joins(table_name, condition)
	return QueryBuilder.new(self):joins(table_name, condition)
end

function Model:group(columns)
	return QueryBuilder.new(self):group(columns)
end

function Model:includes(associations)
	return QueryBuilder.new(self):includes(associations)
end

function Model:where_in(column, values)
	return QueryBuilder.new(self):where_in(column, values)
end

function Model:where_not_in(column, values)
	return QueryBuilder.new(self):where_not_in(column, values)
end

function Model:where_between(column, min_value, max_value)
	return QueryBuilder.new(self):where_between(column, min_value, max_value)
end

function Model:where_like(column, pattern)
	return QueryBuilder.new(self):where_like(column, pattern)
end

function Model:where_null(column)
	return QueryBuilder.new(self):where_null(column)
end

function Model:where_not_null(column)
	return QueryBuilder.new(self):where_not_null(column)
end

function Model:distinct()
	return QueryBuilder.new(self):distinct()
end

function Model:inner_join(table_name, condition)
	return QueryBuilder.new(self):inner_join(table_name, condition)
end

function Model:left_join(table_name, condition)
	return QueryBuilder.new(self):left_join(table_name, condition)
end

---@param self Model Model class (use with : syntax)
---@param attributes table<string, any> Record attributes
---@return table? instance Created and saved record or nil if failed
function Model:create(attributes)
	local instance = self:new(attributes)
	if instance:save() then
		return instance
	else
		return nil
	end
end

-- Bulk insert multiple records
function Model:insert_all(records)
	if #records == 0 then
		return { success = true, inserted_count = 0 }
	end

	-- Get all unique columns from all records
	local all_columns = {}
	local column_set = {}

	for _, record in ipairs(records) do
		for column in pairs(record) do
			if not column_set[column] then
				column_set[column] = true
				table.insert(all_columns, column)
			end
		end
	end

	-- Build VALUES clauses
	local value_clauses = {}
	local all_params = {}

	for _, record in ipairs(records) do
		local placeholders = {}
		for _, column in ipairs(all_columns) do
			table.insert(placeholders, "?")
			table.insert(all_params, record[column])
		end
		table.insert(value_clauses, "(" .. table.concat(placeholders, ", ") .. ")")
	end

	-- Build and execute SQL
	local sql = "INSERT INTO "
		.. self.table_name
		.. " ("
		.. table.concat(all_columns, ", ")
		.. ") VALUES "
		.. table.concat(value_clauses, ", ")

	local result = Database.execute(sql, all_params)

	return {
		success = result.success,
		inserted_count = result.affected_rows,
		first_id = result.last_insert_id - result.affected_rows + 1,
		last_id = result.last_insert_id,
	}
end

-- Create multiple records and return instances
function Model:create_all(records)
	local result = self:insert_all(records)

	if not result.success then
		return nil
	end

	-- Create instances for the inserted records
	local instances = {}
	local current_id = result.first_id

	for _, record_data in ipairs(records) do
		local instance = self:new(record_data)
		instance._attributes[self.primary_key] = current_id
		instance._persisted = true
		table.insert(instances, instance)
		current_id = current_id + 1
	end

	return instances
end

-- Raw SQL methods
function Model:query(sql, params)
	return Database.query(sql, params)
end

function Model:execute(sql, params)
	return Database.execute(sql, params)
end

-- Association registry for model classes
local model_registry = {}

function Model:register_model(class_name, model_class)
	model_registry[class_name] = model_class
end

function Model:get_model_class(class_name)
	return model_registry[class_name]
end

-- Association definition methods
---@param association_name string Association name
---@param options table? Association options (model, foreign_key, etc.)
---@return nil
function Model:belongs_to(association_name, options)
	Associations.register(self, Associations.BELONGS_TO, association_name, options)
end

---@param association_name string Association name
---@param options table? Association options (model, foreign_key, dependent, etc.)
---@return nil
function Model:has_many(association_name, options)
	Associations.register(self, Associations.HAS_MANY, association_name, options)
end

---@param association_name string Association name
---@param options table? Association options (model, foreign_key, dependent, etc.)
---@return nil
function Model:has_one(association_name, options)
	Associations.register(self, Associations.HAS_ONE, association_name, options)
end

-- Association loading methods
function Model:get_belongs_to_association(association_name)
	-- Check if already loaded
	local cached_key = "_" .. association_name
	if self[cached_key] ~= nil then
		return self[cached_key]
	end

	local result = Associations.load_belongs_to(self, association_name)
	self[cached_key] = result
	return result
end

function Model:get_has_many_association(association_name)
	-- Check if already loaded
	local cached_key = "_" .. association_name
	if self[cached_key] ~= nil then
		return self[cached_key]
	end

	-- Return association proxy for lazy loading
	local proxy = Associations.AssociationProxy.new(self, association_name)
	self[cached_key] = proxy
	return proxy
end

function Model:get_has_one_association(association_name)
	-- Check if already loaded
	local cached_key = "_" .. association_name
	if self[cached_key] ~= nil then
		return self[cached_key]
	end

	local result = Associations.load_has_one(self, association_name)
	self[cached_key] = result
	return result
end

return Model
