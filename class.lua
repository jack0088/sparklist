-- 2019 (c) kontakt@herrsch.de


-- Providing object inheritance, the correct way!
-- Getters and setters are supported as well!
-- Classes are linked through __parent objects inside of each (sub-)class until they finally get instanciated
-- (the base-class is assigned as the __index metatable)
-- This way we can extend parent classes or change their methods even after their creation while still being able to see these changes in the sub-classes
-- Instances of classes are deep-copies down their entire inheritance chain
-- (At which point they become unique objects without any relation to their previous parents)


-- Base class for all new (parentless) class objects
-- Only useful to provide important methods across all (sub-)classes
-- Properties and methods of this object are NOT copied to instances of classes!
local class_mt
local cast_mt
local super = {}
super.__index = super

-- Return the parent object of a given class object
-- @object (required table): class object whose parent should be returned
super.parent = function(object) return object.__parent end

-- Check if an object is a parent of nother one
-- @child (required table): reference object whose relation we want to check (the derivant)
-- @parent (required table): relative object which might be the parent of our derivant
super.derivant = function(child, parent) return child:parent() == parent end


-- Guide every access to any table key through this proxy to apply validation checks and inject custom behaviour
-- @object (required table) is a class object whose property we want to (re-)assign or to read
-- @key (required string) is the property we try to access
-- @value (optional of any type) is the new value we want to assign to that @object[@key]
-- returns (any type) the value that the getter, setter or the propery returned
local function proxy(object, key, new_value)
    if type(object) == "nil" or type(key) == "nil" then
        return nil
    end
    
    local current_value = rawget(object, key)
    local parent = rawget(object, "__parent")
    local suffix = tostring(key):lower():match("^[gs]et_(.+)") -- suffix == key but is useful to identify how the key was passed, with or without a get_/set_ prefix
    local getters, setters = {}, {}

    if suffix == nil then -- key doesn't contain get_/set_ prefix so we try to find getter and/or setter for this key
        for property, handler in pairs(object) do -- loops the entire inheritance chain of this object
            local getkey = "get_"..tostring(key)
            local setkey = "set_"..tostring(key)
            if type(handler) == "function" then
                if getkey:match(tostring(property)) == getkey then
                    table.insert(getters, handler)
                elseif setkey:match(tostring(property)) == setkey then
                    table.insert(setters, handler)
                end
            end
        end
    end

    if type(new_value) == "nil" then -- means we look for the value of key
        if suffix ~= nil then -- means we try to access getter's definition function
            return current_value
        end

        -- return value through getter, if any
        assert(#getters < 2, "failed to get value of property as too many matching getters were defined")
        if #getters == 1 then
            return getters[1](object, key) -- getters allowed to return any value, even nil
        end

        -- no getter found, so return plain value
        if type(current_value) ~= "nil" then
            return current_value
        end
        if type(parent) == "table" then
            return parent[key] -- try parent, go through proxy
        end
        return current_value
    end

    if suffix ~= nil then -- means we want to (re-)assing key (specifically the setter definition in this context)
        assert(type(rawget(object, suffix)) == "nil", "getter/setter assignment failed, conflict with already existing property")
        assert(type(new_value) == "function", "getter/setter must be a function value")
        rawset(object, key, new_value)
        return new_value
    end

    -- set value through setter, if any
    assert(#setters < 2, "property assignment failed, too many matching setters were defined")
    if #setters == 1 then
        return setters[1](object, new_value) or new_value -- return value of setter or implicit return of new_value
    end

    -- assing the new value to key without any setter
    assert(type(rawget(object, "get_"..tostring(key))) == "nil", "property assignment failed, conflict with another existing getter")
    rawset(object, key, new_value)
    return new_value
end


-- Make a shallow copy of a class while walking down the entire inheritance chain
-- Call the constructor of the new class instance (if there is any) and return its return value
-- or simply return the new class instance itself, if there the instance has no constructor method
-- @object (required table): class object to deep-copy recursevly
-- @... (optional arguments): argements are passed to the optional class constructor
local function replica(object, ...)
    local copy = object.__parent and replica(object.__parent) or {}
    if object ~= super then
        for k, v in pairs(object) do
            if k ~= "__parent" then -- copy IS now a copy of object.__parent, so just copy the rest of object
                copy[k] = type(v) == "table" and replica(v) or v
            end
        end
    end
    if type(copy.new) == "function" then
        local instance = copy:new(...) or copy
        instance.new = nil -- an instance of a class doesn't need its constructor anymore
        return instance
    end
    return copy
end


-- This wrapper adds a proxy to a class instance to maintain getter/setter support
-- @... (required arguments) the list starts with the class to instanciate from,
-- and is fallowed by optional number and type of arguments to that the instance constructor might need
-- returns (table) an instance of a class
local function cast(object, ...)
    -- NOTE any object copy needs to support getter/setter as well
    -- that's why a metatable with proxy's used here, similar to a class() call
    -- however, if this default metatable has been overriden by developer then use that new one
    -- we just have to hope it has been altered on purpose
    -- because this override could throw off getter/setter support altogether!
    local mt = getmetatable(object)
    if mt == class_mt then mt = cast_mt end
    return setmetatable(replica(object, ...), mt)
end


-- Create a new class object or create a sub-class from an already existing class
-- @parent (optional table): parent class to sub-call from
local function class(parent)
    return setmetatable({__parent = parent or super}, class_mt)
end


cast_mt = {__index = proxy, __newindex = proxy}
class_mt = {__index = proxy, __newindex = proxy, __call = cast}


return class
