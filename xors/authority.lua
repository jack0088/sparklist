-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "xors.hotload"
local class = hotload "xors.class"
local Storage = hotload "xors.kvstorage"
local valid_permissions = hotload "xors.permission"()
local Authority = class(Storage)


-- @name (optional string) name of the authority to act on e.g. "admin", "visitor", "author"
-- @permissions (optional string) list of (default) permission id's for that authority with CSV syntax, e.g. "1; 7; 22; 311;" and is useful to set when authority not exists yet
function Authority:new(name, permissions)
    Storage.new(self, "authorities", "db/acl.db")
    self.column1 = "name"
    self.column2 = "permissions"

    if type(name) == "string" and #name > 0 then
        if type(permissions) == "string" and #permissions > 1 then
            self:set(name, permissions)
        end
        self.name = name
    end
end


function Authority:get_name()
    return self.__name
end


function Authority:set_name(name)
    assert(self:exists(name), "authority named '"..name.."' does not exist yet")
    self.__name = name
    self.exists = function() return self:exists(self.name) end
    self.set = function(...) return self:set(self.name, ...) end
    self.get = function() return self:get(self.name) end
    self.addPermission = function(...) return self:addPermission(self.name, ...) end
    self.removePermission = function(...) return self.removePermission(self.name, ...) end
    self.hasPermission = function(...) return self:hasPermission(self.name, ...) end
end


function Authority:exists(name)
    return name ~= nil and not not Storage.exists(self, name)
end


function Authority:set(name, permissions)
    -- convert string into table
    if type(permissions) == "string" then
        local t = {}
        for id in permissions:gmatch("%d+") do
            table.insert(t, id)
        end
        permissions = t
    end
    -- order permission id's and remove duplicates
    if type(permissions) == "table" then
        table.sort(permissions)
        for pos = getn(permissions), 1, -1 do
            if tonumber(permissions[pos]) == tonumber(permissions[pos - 1]) then
                table.remove(permissions, pos)
            end
        end
    end
    -- convert table back into a string with CSV syntax and save into db
    Storage.set(name, table.concat(permissions, "; ")..";")
end


function Authority:addPermission(authority, permission)
    if type(tonumber(permission)) ~= "number" then
        permission = valid_permissions:getId(permission)
    end
    assert(valid_permissions:exists(permission), string.format(
        "could not add permission '%s' to authority '%s' because such permission does not exist",
        permission,
        authority
    ))
    self:set(authority, self:get(authority).." "..permission..";")
end


function Authority:removePermission(authority, permission)
    if type(tonumber(permission)) ~= "number" then
        permission = valid_permissions:getId(permission)
    end
    if type(tonumber(permission)) == "number" then
        local permissions = {}
        for id in self:get(authority):gmatch("%d+") do
            if tonumber(id) ~= tonumber(permission) then
                table.insert(permissions, id)
            end
        end
        self:set(authority, permissions)
    end
end


function Authority:hasPermission(authority, permission)
    if type(tonumber(permission)) ~= "number" then
        permission = valid_permissions:getId(permission)
    end
    if valid_permissions:exists(permission) then
        for id in self:get(authority):gmatch("%d+") do
            if tonumber(id) == tonumber(permission) then
                return true
            end
        end
    end
    return false
end


return Authority
