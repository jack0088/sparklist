-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local Storage = hotload "kvstorage"
local Permission = class(Storage)


function Permission:new(name, description)
    Storage.new(self, "permissions", "db/acl.db")
    self.column1 = "name"
    self.column2 = "description"
    self:set(name, permission)
end


function Permission:exists(name)
    if type(tonumber(name)) == "number" then -- id!
        local records = self.db:run(
            "select id from '%s' where id = %s",
            self.table, name
        )
        return getn(records) > 0 and record[1].id == tonumber(name) or false
    end
    return not not Storage.exists(self, name)
end


return Permission
