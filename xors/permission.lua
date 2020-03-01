-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local KVStorage = hotload "kvstorage"
local Permission = class(KVStorage)


function Permission:new()
    KVStorage.new(self, "permissions", "name", "description", "db/acl.db")
end


function Permission:exists(identifier)
    if type(identifier) == "nil" then
        return false
    end
    if type(tonumber(identifier)) == "number" and tonumber(identifier) > 0 then -- check by id
        local records = self:run("select id from '%s' where id = %s", self.table, identifier)
        return getn(records) > 0 and tonumber(record[1].id) == tonumber(identifier) or false
    end
    return not not KVStorage.exists(self, identifier) -- check by name
end


return Permission
