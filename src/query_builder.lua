-- Query Builder for constructing SQL queries
local Database = require("carga.src.database")
local Associations = require("carga.src.associations")

local QueryBuilder = {}
QueryBuilder.__index = QueryBuilder

-- Create new query builder instance
function QueryBuilder.new(model_class)
    local builder = setmetatable({
        model_class = model_class,
        table_name = model_class.table_name,
        select_clause = "*",
        where_conditions = {},
        join_clauses = {},
        order_clauses = {},
        group_clauses = {},
        having_clauses = {},
        limit_value = nil,
        offset_value = nil,
        params = {},
        includes_list = {}
    }, QueryBuilder)
    
    return builder
end

-- Clone query builder for chaining
function QueryBuilder:clone()
    local new_builder = QueryBuilder.new(self.model_class)
    new_builder.select_clause = self.select_clause
    new_builder.where_conditions = {}
    new_builder.join_clauses = {}
    new_builder.order_clauses = {}
    new_builder.group_clauses = {}
    new_builder.having_clauses = {}
    new_builder.params = {}
    
    -- Deep copy arrays
    for _, condition in ipairs(self.where_conditions) do
        table.insert(new_builder.where_conditions, condition)
    end
    for _, join in ipairs(self.join_clauses) do
        table.insert(new_builder.join_clauses, join)
    end
    for _, order in ipairs(self.order_clauses) do
        table.insert(new_builder.order_clauses, order)
    end
    for _, group in ipairs(self.group_clauses) do
        table.insert(new_builder.group_clauses, group)
    end
    for _, having in ipairs(self.having_clauses) do
        table.insert(new_builder.having_clauses, having)
    end
    for _, param in ipairs(self.params) do
        table.insert(new_builder.params, param)
    end
    
    new_builder.limit_value = self.limit_value
    new_builder.offset_value = self.offset_value
    
    -- Copy includes list
    new_builder.includes_list = {}
    for _, include in ipairs(self.includes_list) do
        table.insert(new_builder.includes_list, include)
    end
    
    return new_builder
end

-- SELECT clause
function QueryBuilder:select(columns)
    local builder = self:clone()
    if type(columns) == "table" then
        builder.select_clause = table.concat(columns, ", ")
    else
        builder.select_clause = columns
    end
    return builder
end

-- WHERE clause
function QueryBuilder:where(conditions, params)
    local builder = self:clone()
    
    if type(conditions) == "table" then
        -- Hash conditions: { name = "John", age = 25 }
        for column, value in pairs(conditions) do
            table.insert(builder.where_conditions, column .. " = ?")
            table.insert(builder.params, value)
        end
    elseif type(conditions) == "string" then
        -- Raw SQL condition: "age > ?"
        table.insert(builder.where_conditions, conditions)
        if params then
            for _, param in ipairs(params) do
                table.insert(builder.params, param)
            end
        end
    end
    
    return builder
end

-- OR WHERE clause
function QueryBuilder:or_where(conditions, params)
    local builder = self:clone()
    
    if #builder.where_conditions > 0 then
        local last_condition = table.remove(builder.where_conditions)
        if type(conditions) == "table" then
            local or_conditions = {}
            for column, value in pairs(conditions) do
                table.insert(or_conditions, column .. " = ?")
                table.insert(builder.params, value)
            end
            table.insert(builder.where_conditions, "(" .. last_condition .. " OR " .. table.concat(or_conditions, " AND ") .. ")")
        else
            table.insert(builder.where_conditions, "(" .. last_condition .. " OR " .. conditions .. ")")
            if params then
                for _, param in ipairs(params) do
                    table.insert(builder.params, param)
                end
            end
        end
    else
        return builder:where(conditions, params)
    end
    
    return builder
end

-- JOIN clause
function QueryBuilder:joins(table_name, condition)
    local builder = self:clone()
    condition = condition or (self.table_name .. ".id = " .. table_name .. "." .. self.table_name:sub(1, -2) .. "_id")
    table.insert(builder.join_clauses, "INNER JOIN " .. table_name .. " ON " .. condition)
    return builder
end

-- LEFT JOIN clause
function QueryBuilder:left_joins(table_name, condition)
    local builder = self:clone()
    condition = condition or (self.table_name .. ".id = " .. table_name .. "." .. self.table_name:sub(1, -2) .. "_id")
    table.insert(builder.join_clauses, "LEFT JOIN " .. table_name .. " ON " .. condition)
    return builder
end

-- RIGHT JOIN clause
function QueryBuilder:right_joins(table_name, condition)
    local builder = self:clone()
    condition = condition or (self.table_name .. ".id = " .. table_name .. "." .. self.table_name:sub(1, -2) .. "_id")
    table.insert(builder.join_clauses, "RIGHT JOIN " .. table_name .. " ON " .. condition)
    return builder
end

-- INNER JOIN with explicit condition
function QueryBuilder:inner_join(table_name, condition)
    local builder = self:clone()
    table.insert(builder.join_clauses, "INNER JOIN " .. table_name .. " ON " .. condition)
    return builder
end

-- LEFT JOIN with explicit condition
function QueryBuilder:left_join(table_name, condition)
    local builder = self:clone()
    table.insert(builder.join_clauses, "LEFT JOIN " .. table_name .. " ON " .. condition)
    return builder
end

-- ORDER BY clause
function QueryBuilder:order(column, direction)
    local builder = self:clone()
    
    -- Handle cases like "created_at DESC" or "name ASC"
    if column:match("%s+") then
        -- Column already contains direction
        table.insert(builder.order_clauses, column)
    else
        -- Separate column and direction
        direction = direction or "ASC"
        table.insert(builder.order_clauses, column .. " " .. direction:upper())
    end
    
    return builder
end

-- GROUP BY clause
function QueryBuilder:group(columns)
    local builder = self:clone()
    if type(columns) == "table" then
        for _, column in ipairs(columns) do
            table.insert(builder.group_clauses, column)
        end
    else
        table.insert(builder.group_clauses, columns)
    end
    return builder
end

-- HAVING clause
function QueryBuilder:having(condition, params)
    local builder = self:clone()
    table.insert(builder.having_clauses, condition)
    if params then
        for _, param in ipairs(params) do
            table.insert(builder.params, param)
        end
    end
    return builder
end

-- LIMIT clause
function QueryBuilder:limit(count)
    local builder = self:clone()
    builder.limit_value = count
    return builder
end

-- OFFSET clause
function QueryBuilder:offset(count)
    local builder = self:clone()
    builder.offset_value = count
    return builder
end

-- INCLUDES clause for eager loading
function QueryBuilder:includes(associations)
    local builder = self:clone()
    
    if type(associations) == "string" then
        table.insert(builder.includes_list, associations)
    elseif type(associations) == "table" then
        for _, association in ipairs(associations) do
            table.insert(builder.includes_list, association)
        end
    end
    
    return builder
end

-- WHERE IN clause
function QueryBuilder:where_in(column, values)
    local builder = self:clone()
    
    if #values == 0 then
        table.insert(builder.where_conditions, "1=0")
        return builder
    end
    
    local placeholders = {}
    for _, value in ipairs(values) do
        table.insert(placeholders, "?")
        table.insert(builder.params, value)
    end
    
    table.insert(builder.where_conditions, column .. " IN (" .. table.concat(placeholders, ", ") .. ")")
    return builder
end

-- WHERE NOT IN clause
function QueryBuilder:where_not_in(column, values)
    local builder = self:clone()
    
    if #values == 0 then
        return builder
    end
    
    local placeholders = {}
    for _, value in ipairs(values) do
        table.insert(placeholders, "?")
        table.insert(builder.params, value)
    end
    
    table.insert(builder.where_conditions, column .. " NOT IN (" .. table.concat(placeholders, ", ") .. ")")
    return builder
end

-- WHERE BETWEEN clause
function QueryBuilder:where_between(column, min_value, max_value)
    local builder = self:clone()
    table.insert(builder.where_conditions, column .. " BETWEEN ? AND ?")
    table.insert(builder.params, min_value)
    table.insert(builder.params, max_value)
    return builder
end

-- WHERE LIKE clause
function QueryBuilder:where_like(column, pattern)
    local builder = self:clone()
    table.insert(builder.where_conditions, column .. " LIKE ?")
    table.insert(builder.params, pattern)
    return builder
end

-- WHERE IS NULL clause
function QueryBuilder:where_null(column)
    local builder = self:clone()
    table.insert(builder.where_conditions, column .. " IS NULL")
    return builder
end

-- WHERE IS NOT NULL clause
function QueryBuilder:where_not_null(column)
    local builder = self:clone()
    table.insert(builder.where_conditions, column .. " IS NOT NULL")
    return builder
end

-- DISTINCT clause
function QueryBuilder:distinct()
    local builder = self:clone()
    if not builder.select_clause:match("^DISTINCT") then
        builder.select_clause = "DISTINCT " .. builder.select_clause
    end
    return builder
end

-- Build SELECT SQL
function QueryBuilder:to_sql()
    local sql_parts = { "SELECT " .. self.select_clause }
    table.insert(sql_parts, "FROM " .. self.table_name)
    
    -- JOIN clauses
    for _, join in ipairs(self.join_clauses) do
        table.insert(sql_parts, join)
    end
    
    -- WHERE clause
    if #self.where_conditions > 0 then
        table.insert(sql_parts, "WHERE " .. table.concat(self.where_conditions, " AND "))
    end
    
    -- GROUP BY clause
    if #self.group_clauses > 0 then
        table.insert(sql_parts, "GROUP BY " .. table.concat(self.group_clauses, ", "))
    end
    
    -- HAVING clause
    if #self.having_clauses > 0 then
        table.insert(sql_parts, "HAVING " .. table.concat(self.having_clauses, " AND "))
    end
    
    -- ORDER BY clause
    if #self.order_clauses > 0 then
        table.insert(sql_parts, "ORDER BY " .. table.concat(self.order_clauses, ", "))
    end
    
    -- LIMIT clause
    if self.limit_value then
        table.insert(sql_parts, "LIMIT " .. self.limit_value)
    end
    
    -- OFFSET clause
    if self.offset_value then
        table.insert(sql_parts, "OFFSET " .. self.offset_value)
    end
    
    return table.concat(sql_parts, " ")
end

-- Execute query and return results
function QueryBuilder:all()
    local sql = self:to_sql()
    local result = Database.query(sql, self.params)
    
    -- Convert rows to model instances
    local instances = {}
    for _, row in ipairs(result.rows) do
        local instance = self.model_class:new(row)
        instance._persisted = true
        table.insert(instances, instance)
    end
    
    -- Eager load associations if specified
    if #self.includes_list > 0 then
        Associations.eager_load(instances, self.includes_list)
    end
    
    return instances
end

-- Get first result
function QueryBuilder:first()
    local results = self:limit(1):all()
    return results[1]
end

-- Get last result
function QueryBuilder:last()
    local results = self:order("id", "DESC"):limit(1):all()
    return results[1]
end

-- Count results
function QueryBuilder:count()
    local builder = self:clone()
    builder.select_clause = "COUNT(*) as count"
    builder.order_clauses = {}
    builder.limit_value = nil
    builder.offset_value = nil
    
    local sql = builder:to_sql()
    local result = Database.query(sql, self.params)
    
    return result.rows[1] and result.rows[1].count or 0
end

-- Check if any results exist
function QueryBuilder:exists()
    return self:count() > 0
end

-- Find by ID
function QueryBuilder:find(id)
    return self:where({ id = id }):first()
end

-- Find by conditions
function QueryBuilder:find_by(conditions)
    return self:where(conditions):first()
end

-- Update all matching records
function QueryBuilder:update_all(attributes)
    local set_clauses = {}
    local params = {}
    
    for column, value in pairs(attributes) do
        table.insert(set_clauses, column .. " = ?")
        table.insert(params, value)
    end
    
    -- Add WHERE parameters
    for _, param in ipairs(self.params) do
        table.insert(params, param)
    end
    
    local sql = "UPDATE " .. self.table_name .. " SET " .. table.concat(set_clauses, ", ")
    
    if #self.where_conditions > 0 then
        sql = sql .. " WHERE " .. table.concat(self.where_conditions, " AND ")
    end
    
    return Database.execute(sql, params)
end

-- Delete all matching records
function QueryBuilder:destroy_all()
    local sql = "DELETE FROM " .. self.table_name
    
    if #self.where_conditions > 0 then
        sql = sql .. " WHERE " .. table.concat(self.where_conditions, " AND ")
    end
    
    return Database.execute(sql, self.params)
end

return QueryBuilder