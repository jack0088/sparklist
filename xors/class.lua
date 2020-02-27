-- 2019 (c) kontakt@herrsch.de


-- Providing object inheritance, the correct way!
-- Support for getters and setters!
-- (Getter/Setter name can even be a regex expression! - But be careful your namin as "get_%w+" for example would override the entire standard proxy behaviour of class_mt.__index or cast_mt.__index - This can be either a powerful feature or produce unintended results.)
-- Classes are linked through __parent objects inside of each (sub-)class until they finally get instanciated
-- (the base-class is assigned as the __index metatable)
-- This way we can extend parent classes or change their methods even after their creation while still being able to see these changes in the sub-classes
-- Instances of classes are deep-copies down their entire inheritance chain
-- (At which point they become unique objects without any relation to their previous parents)

local unpack = unpack or table.unpack -- Lua > 5.1

-- Cache of the metatables we need for proxies to support inheritance and getters/setters
-- they will be set at later time, but need to reference earlier in code, thus this workaround
local class_mt
local cast_mt

-- Base class for all new (parentless) class objects
-- Only useful to provide important methods across all (sub-)classes
-- Properties and methods of this object are NOT copied to instances of classes!
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
-- @read_mode (boolean) flag to identify __index vs __newindex
-- returns (any type) the value that the getter, setter or the propery returned
local function proxy(object, key, new_value, read_mode)
    if type(object) ~= "table" or type(key) == "nil" then
        return nil
    end
    
    local current_value = rawget(object, key)
    local parent = rawget(object, "__parent")
    local prefix = tostring(key):sub(1, 4):lower():match("^[gs]et_$") -- "get_" or "set_" or nil
    local getter = rawget(object, "get_"..tostring(key))
    local setter = rawget(object, "set_"..tostring(key))

    if read_mode == true then -- means we look for the value of key
        if prefix ~= nil then -- means we try to access getter's or setter's definition function
            return current_value
        end
        if type(getter) == "function" then
            return getter(object) -- getters allowed to return any value, even nil
        end
        if type(current_value) ~= "nil" then
            return current_value -- plain value
        end
        if type(parent) == "table" then
            return parent[key] -- try parent, go through proxy
        end
        return current_value
    end

    if prefix ~= nil then -- means we want to (re-)assing getter or setter
        local whois = prefix == "get_" and "getter" or "setter"
        local property = tostring(key):sub(4) -- suffix
        assert(type(rawget(object, property)) == "nil", debug.traceback(whois.." assignment failed, conflict with already existing property"))
        assert(type(new_value) == "function", debug.traceback(whois.." must be a function value"))
        rawset(object, key, new_value)
        return new_value
    end
    if type(setter) == "function" then
        return setter(object, new_value) or new_value -- return value of setter or implicit return of new_value
    end
    assert(type(getter) == "nil", debug.traceback("property assignment failed, conflict with existing getter"))
    rawset(object, key, new_value) -- plain value assignment
    return new_value
end


-- Make a shallow copy of a class while walking down the entire inheritance chain
-- Call the constructor of the new class instance (if there is any) and return its return value
-- or simply return the new class instance itself, if there the instance has no constructor method
-- @object (required table): class object to deep-copy recursevly
-- @... (optional arguments): argements are passed to the optional class constructor
local function replica(object)
    local copy = object.__parent and replica(object.__parent) or {}
    if object ~= super then
        for k, v in pairs(object) do
            local prefix = k:sub(1, 4)
            if k ~= "__parent" and prefix ~= "get_" and prefix ~= "set_" then
                 -- copy IS now a copy of object.__parent, so just add the rest of the object to it
                copy[k] = type(v) == "table" and replica(v) or v
            end
        end
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
    local copy = setmetatable(replica(object), mt)
    if type(copy.new) == "function" then
        local instance = copy:new(...) or copy
        instance.new = nil -- an instance of a class doesn't need its constructor anymore
        return instance
    end
    return copy
end


local readproxy = function(t, k) return proxy(t, k, nil, true) end
cast_mt = {__index = readproxy, __newindex = proxy}
class_mt = {__index = readproxy, __newindex = proxy, __call = cast}


-- Create a new class object or create a sub-class from an already existing class
-- @parent (optional table): parent class to sub-call from
-- IMPORTANT NOTE getters and setters are never copied over to sub-classes or class-instances as they may reference to upvalues!
-- So if you need them in your sub-class, just re-assing them manually from their __parent
local function class(parent)
    return setmetatable({__parent = parent or super}, class_mt)
end


return class
