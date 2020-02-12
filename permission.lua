-- 2020 (c) kontakt@herrsch.de


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
    return not not Storage.exists(self, name)
end


return Permission
