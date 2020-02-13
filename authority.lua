-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local Storage = hotload "kvstorage"
local valid_permissions = hotload "permissions"()
local Authority = class(Storage)


-- @name (optional string) name of the authority to act on e.g. "admin", "visitor"
-- @permissions (optional string) list of (default) permission id's for that authority with CSV syntax, e.g. "1; 7; 22; 311;" and is useful to set when authority not exists yet
function Authority:new(name, permissions)
    assert(name, "missing permission group name")
    Storage.new(self, "groups", "db/acl.db")
    self.column1 = "name"
    self.column2 = "permissions"

    if type(permissions) == "string" and #permissions > 1 then
        Storage.set(self, name, permissions)
    end

    if name ~= nil then
        self.name = name
    end
end


function Authority:get_name()
    return self.__name
end


function Authority:set_name(name)
    assert(self:exists(), "permission group named '"..name.."' does not exist yet")
    self.__name = name
    self.exists = function() return self:exists(self.name) end
    self.set = function(...) return self:set(self.name, ...) end
    self.get = function() return self:get(self.name) end
    self.addPermission = function(...) return self:addPermission(self.name, ...) end
    self.removePermission = function(...) return self.removePermission(self.name, ...) end
    self.hasPermission = function(...) return self:addPermission(self.name, ...) end
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
            if permissions[pos] == permissions[pos - 1] then
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
        local permissions = self:get(authority)
        local i, j = permissions:sub(permissions:find("[%s;]+"..permission..";") or -1):match("%d+")
        if i and j then
            self:set(authority, permissions:sub(1, i - 1)..permissions:sub(j + 1))
        end
    end
end


function Authority:hasPermission(authority, permission)
    if type(tonumber(permission)) ~= "number" then
        permission = valid_permissions:getId(permission)
    end
    return
        valid_permissions:exists(permission)
        and tonumber(self:get(authority):match("[%s;]+("..permission..");") or 0) == tonumber(permission)
end


return Authority
