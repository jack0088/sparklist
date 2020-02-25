-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "xors.hotload"
local class = hotload "xors.class"
local Storage = hotload "xors.kvstorage"
local valid_permissions = hotload "xors.permission"()
local valid_authorities = hotload "xors.authority"()
local User = class(Storage)


function User:new(email, authorities)
    Storage.new(self, "users", "db/acl.db")
    self.column1 = "email"
    self.column2 = "authorities"

    if type(email) == "string" and #email > 0 then
        if type(authorities) == "string" and #authorities > 1 then
            self:set(email, authorities)
        end
        self.email = email
    end
end


function User:get_email()
    return self.__email
end


function User:set_email(email)
    assert(email:match("(.+)@(.+%.%w%w[%w%p]*)$") ~= nil, "invalid email pattern")
    assert(self:exists(email), "user with email '"..email.."' does not exist yet")
    self.__email = email
    self.exists = function() return self:exists(self.email) end
    self.set = function(...) return self:set(self.email, ...) end
    self.get = function() return self:get(self.email) end
    self.authenticated = function() return self:authenticated(self.email) end
    self.hasAuthority = function(...) return self:hasAuthority(self.email, ...) end
    self.hasPermission = function(...) return self:hasPermission(self.email, ...) end
end


function User:exists(email)
    return email ~= nil and not not Storage.exists(self, email)
end


function User:set(email, authorities)
    assert(email:match("(.+)@(.+%.%w%w[%w%p]*)$") ~= nil, "invalid email pattern")
    -- convert string into table
    if type(authorities) == "string" then
        local t = {}
        for email_address in authorities:gmatch("[^%s;]+") do
            table.insert(t, email_address)
        end
        authorities = t
    end
    -- order permission id's and remove duplicates
    if type(authorities) == "table" then
        table.sort(authorities)
        for pos = getn(authorities), 1, -1 do
            if tonumber(authorities[pos]) == tonumber(authorities[pos - 1]) then
                table.remove(authorities, pos)
            end
        end
    end
    -- convert table back into a string with CSV syntax and save into db
    Storage.set(email, table.concat(authorities, "; ")..";")
end


function User:hasAuthority(email, authority)
    -- TODO
end


function User:hasPermission(email, permission)
    -- TODO
end


function User:authenticated(email)
    -- TODO
    return false
end


return User
