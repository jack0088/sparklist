-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local Storage = hotload "kvstorage"
local Permission = class(Storage)


function Permission:new()
    Storage.new(self, "permissions", "db/acl.db")
    self.column1 = "name"
    self.column2 = "description"
end


function Permission:exists(n)
    if type(tonumber(n)) == "number" then -- check by id
        local records = self.db:run(
            "select id from '%s' where id = %s",
            self.table, n
        )
        return getn(records) > 0 and record[1].id == tonumber(n) or false
    end
    return not not Storage.exists(self, n) -- check by name
end


return Permission
