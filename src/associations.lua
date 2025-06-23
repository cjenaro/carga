-- Association management for Carga ORM
local Database = require("carga.src.database")

local Associations = {}

-- Association types
local BELONGS_TO = "belongs_to"
local HAS_MANY = "has_many"
local HAS_ONE = "has_one"

-- Association registry
local association_registry = {}

-- Register an association
function Associations.register(model_class, association_type, association_name, options)
    options = options or {}
    
    local class_name = model_class.class_name
    if not association_registry[class_name] then
        association_registry[class_name] = {}
    end
    
    association_registry[class_name][association_name] = {
        type = association_type,
        name = association_name,
        class_name = options.class_name or Associations.infer_class_name(association_name, association_type),
        foreign_key = options.foreign_key or Associations.infer_foreign_key(association_name, association_type, model_class),
        primary_key = options.primary_key or "id",
        dependent = options.dependent or nil,
        through = options.through or nil
    }
end

-- Get associations for a model class
function Associations.get_associations(model_class)
    return association_registry[model_class.class_name] or {}
end

-- Get specific association
function Associations.get_association(model_class, association_name)
    local associations = Associations.get_associations(model_class)
    return associations[association_name]
end

-- Infer class name from association name
function Associations.infer_class_name(association_name, association_type)
    if association_type == HAS_MANY then
        -- posts -> Post
        local singular = association_name:gsub("s$", "")
        return singular:gsub("^%l", string.upper)
    else
        -- user -> User, company -> Company
        return association_name:gsub("^%l", string.upper)
    end
end

-- Infer foreign key from association
function Associations.infer_foreign_key(association_name, association_type, model_class)
    if association_type == BELONGS_TO then
        -- belongs_to :user -> user_id
        return association_name .. "_id"
    else
        -- has_many :posts -> user_id (in posts table)
        return string.lower(model_class.class_name) .. "_id"
    end
end

-- Load belongs_to association
function Associations.load_belongs_to(instance, association_name)
    local model_class = instance._model_class
    local association = Associations.get_association(model_class, association_name)
    
    if not association then
        return nil
    end
    
    local foreign_id = instance:get_attribute(association.foreign_key)
    if not foreign_id then
        return nil
    end
    
    local associated_class = model_class:get_model_class(association.class_name)
    if not associated_class then
        error("Model class not found: " .. association.class_name)
    end
    
    return associated_class:find(foreign_id)
end

-- Load has_many association
function Associations.load_has_many(instance, association_name)
    local model_class = instance._model_class
    local association = Associations.get_association(model_class, association_name)
    
    if not association then
        return {}
    end
    
    local my_id = instance:get_attribute(association.primary_key)
    if not my_id then
        return {}
    end
    
    local associated_class = model_class:get_model_class(association.class_name)
    if not associated_class then
        error("Model class not found: " .. association.class_name)
    end
    
    return associated_class:where({ [association.foreign_key] = my_id })
end

-- Load has_one association
function Associations.load_has_one(instance, association_name)
    local model_class = instance._model_class
    local association = Associations.get_association(model_class, association_name)
    
    if not association then
        return nil
    end
    
    local my_id = instance:get_attribute(association.primary_key)
    if not my_id then
        return nil
    end
    
    local associated_class = model_class:get_model_class(association.class_name)
    if not associated_class then
        error("Model class not found: " .. association.class_name)
    end
    
    return associated_class:find_by({ [association.foreign_key] = my_id })
end

-- Eager load associations for multiple instances
function Associations.eager_load(instances, association_names)
    if #instances == 0 then
        return instances
    end
    
    local model_class = instances[1]._model_class
    
    for _, association_name in ipairs(association_names) do
        local association = Associations.get_association(model_class, association_name)
        if association then
            if association.type == BELONGS_TO then
                Associations.eager_load_belongs_to(instances, association)
            elseif association.type == HAS_MANY then
                Associations.eager_load_has_many(instances, association)
            elseif association.type == HAS_ONE then
                Associations.eager_load_has_one(instances, association)
            end
        end
    end
    
    return instances
end

-- Eager load belongs_to associations
function Associations.eager_load_belongs_to(instances, association)
    local model_class = instances[1]._model_class
    local associated_class = model_class:get_model_class(association.class_name)
    
    if not associated_class then
        error("Model class not found: " .. association.class_name)
    end
    
    -- Collect foreign IDs
    local foreign_ids = {}
    local id_to_instances = {}
    
    for _, instance in ipairs(instances) do
        local foreign_id = instance:get_attribute(association.foreign_key)
        if foreign_id then
            foreign_ids[foreign_id] = true
            if not id_to_instances[foreign_id] then
                id_to_instances[foreign_id] = {}
            end
            table.insert(id_to_instances[foreign_id], instance)
        end
    end
    
    if next(foreign_ids) then
        -- Build IN clause
        local ids = {}
        for id in pairs(foreign_ids) do
            table.insert(ids, id)
        end
        
        -- Load associated records
        local associated_records = associated_class:where("id IN (" .. table.concat(ids, ",") .. ")"):all()
        
        -- Map records to instances
        for _, record in ipairs(associated_records) do
            local record_id = record:get_attribute("id")
            if id_to_instances[record_id] then
                for _, instance in ipairs(id_to_instances[record_id]) do
                    instance["_" .. association.name] = record
                end
            end
        end
    end
end

-- Eager load has_many associations
function Associations.eager_load_has_many(instances, association)
    local model_class = instances[1]._model_class
    local associated_class = model_class:get_model_class(association.class_name)
    
    if not associated_class then
        error("Model class not found: " .. association.class_name)
    end
    
    -- Collect primary IDs
    local primary_ids = {}
    local id_to_instance = {}
    
    for _, instance in ipairs(instances) do
        local primary_id = instance:get_attribute(association.primary_key)
        if primary_id then
            primary_ids[primary_id] = true
            id_to_instance[primary_id] = instance
            instance["_" .. association.name] = {}
        end
    end
    
    if next(primary_ids) then
        -- Build IN clause
        local ids = {}
        for id in pairs(primary_ids) do
            table.insert(ids, id)
        end
        
        -- Load associated records
        local associated_records = associated_class:where(association.foreign_key .. " IN (" .. table.concat(ids, ",") .. ")"):all()
        
        -- Group records by foreign key
        for _, record in ipairs(associated_records) do
            local foreign_id = record:get_attribute(association.foreign_key)
            if id_to_instance[foreign_id] then
                table.insert(id_to_instance[foreign_id]["_" .. association.name], record)
            end
        end
    end
end

-- Eager load has_one associations
function Associations.eager_load_has_one(instances, association)
    local model_class = instances[1]._model_class
    local associated_class = model_class:get_model_class(association.class_name)
    
    if not associated_class then
        error("Model class not found: " .. association.class_name)
    end
    
    -- Collect primary IDs
    local primary_ids = {}
    local id_to_instance = {}
    
    for _, instance in ipairs(instances) do
        local primary_id = instance:get_attribute(association.primary_key)
        if primary_id then
            primary_ids[primary_id] = true
            id_to_instance[primary_id] = instance
        end
    end
    
    if next(primary_ids) then
        -- Build IN clause
        local ids = {}
        for id in pairs(primary_ids) do
            table.insert(ids, id)
        end
        
        -- Load associated records
        local associated_records = associated_class:where(association.foreign_key .. " IN (" .. table.concat(ids, ",") .. ")"):all()
        
        -- Map records to instances
        for _, record in ipairs(associated_records) do
            local foreign_id = record:get_attribute(association.foreign_key)
            if id_to_instance[foreign_id] then
                id_to_instance[foreign_id]["_" .. association.name] = record
            end
        end
    end
end

-- Association proxy for has_many relationships
local AssociationProxy = {}
AssociationProxy.__index = AssociationProxy

function AssociationProxy.new(instance, association_name)
    return setmetatable({
        instance = instance,
        association_name = association_name,
        _loaded = false,
        _records = nil
    }, AssociationProxy)
end

function AssociationProxy:load()
    if not self._loaded then
        self._records = Associations.load_has_many(self.instance, self.association_name):all()
        self._loaded = true
    end
    return self._records
end

function AssociationProxy:all()
    return self:load()
end

function AssociationProxy:where(conditions, params)
    local query = Associations.load_has_many(self.instance, self.association_name)
    return query:where(conditions, params)
end

function AssociationProxy:count()
    local query = Associations.load_has_many(self.instance, self.association_name)
    return query:count()
end

function AssociationProxy:create(attributes)
    local model_class = self.instance._model_class
    local association = Associations.get_association(model_class, self.association_name)
    
    if not association then
        error("Association not found: " .. self.association_name)
    end
    
    local associated_class = model_class:get_model_class(association.class_name)
    if not associated_class then
        error("Model class not found: " .. association.class_name)
    end
    
    -- Set foreign key
    attributes = attributes or {}
    attributes[association.foreign_key] = self.instance:get_attribute(association.primary_key)
    
    local record = associated_class:create(attributes)
    
    -- Invalidate cache
    self._loaded = false
    self._records = nil
    
    return record
end

-- Export association types and main module
Associations.BELONGS_TO = BELONGS_TO
Associations.HAS_MANY = HAS_MANY
Associations.HAS_ONE = HAS_ONE
Associations.AssociationProxy = AssociationProxy

return Associations