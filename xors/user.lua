-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local KVStorage = hotload "kvstorage"
local Authority = hotload "authority"
local permission_groups = Authority()
local User = class(Authority)


-- @address (required string) an email, at least 6 characters length, e.g. "a@b.at"
-- returns (boolean) true for email that meeets requirements, otherwise false
User.validEmail = function(address)
    if type(address) ~= "string" or #address < 6 then return false end
    local validation = address:match("(.+)@(.+%.%w%w[%w%p]*)$") ~= nil
    local message = "invalid email pattern"
    return validation, validation and nil or message
end


-- @email (optional string) valid email or @session to bind the class instance to (to call methods on)
-- @authorities (optional string) permission names assigned to this @email/@session with CSV based encoding, e.g. "read_posts; email.options.send; blog-create-draft*;"
-- @session (optional string) unique session hash of the client (32 characters long by default)
-- NOTE first parameter can be either @email OR @session; if it's @session, then @email is fetched from db
function User:new(email, authorities, session)
    KVStorage.new(self, "users", "email", "authorities", "db/acl.db")
    self.column3 = "session"

    if not self.validEmail(email) and type(email) == "string" then
        local usr = self:run(
            "select * from '%s' where %s = '%s'",
            self.table, self.column3, tostring(email)
        )
        assert(getn(usr) <= 1, "one session belongs to multiple users (prohibited behaviour)")
        if usr[1] and usr[1].session == email then
            email = usr[1].email
            session = usr[1].session
        end
    end

    if self.validEmail(email) then
        if (type(authorities) == "table" and getn(authorities) > 0)
        or (type(authorities) == "string" and #authorities > 1)
        then
            User.set(self, email, authorities, session)
        end
        self.identifier = email
        User.purge(self, self.identifier)
    end
end


function User:create(table)
    if type(table) == "string" and #table > 0 then
        self:run(
            [[create table if not exists '%s' (
                id integer primary key autoincrement,
                %s text unique not null,
                %s text not null,
                %s text unique
            )]],
            table,
            "key",
            "value",
            "optional"
        )
    end
end


function User:get_column3()
    return self.__columnname3 or "optional"
end


function User:set_column3(name)
    if type(name) == "string" and #name > 0 then
        if self.column3 ~= name then
            self:rename(self.table, self.column3, name)
        end
        self.__columnname3 = name
    end
end


function User:set_identifier(email)
    assert(self.validEmail(email))
    Authority.set_identifier(self, email)
    local wrappable_methods = {
        "setSession",
        "hasAuthority",
        "addAuthority",
        "removeAuthority"
    }
    for _, method in ipairs(wrappable_methods) do
        self[method] = function(...) return self[method](self.identifier, ...) end
    end
end


-- get @authorities and @session of user with @email; if passing @authorities as well you get the id of that record in db
-- @email (required string)
-- @authorities (optional string)
function User:get(email, authorities)
    local value = KVStorage.get(self, email, authorities) -- value or id
    local session
    if value and type(value) ~= "table" and session == nil then
        local records
        if type(tonumber(value)) == "number" then
            records = self:run(
                "select %s from '%s' where id = %s",
                self.column3, self.table, value
            )
        else
            records = self:run(
                "select %s from '%s' where %s = '%s' and %s = '%s'",
                self.column3, self.table, self.column1, tostring(email), self.column2, value
            )
        end
        session = (type(session) == "table" and getn(records) > 0) and records[1][self.column3] or nil
    end
    return value, session
end


-- @email (required string)
-- @authorities (optional string) new set of permission names to assign to the user with this @email
-- @session (optional string) unique client session hash; or pass "null" to explicitly delete current reference; alternatively call User.setSession(email, hash) to set this property in db
function User:set(email, authorities, session)
    assert(self.validEmail(email))
    Authority.set(self, email, authorities)
    if session ~= nil then
        User.setSession(self, email, session) -- update
    end
end


-- @email (required string)
-- @uid (required string or nil) nil will set db column to null wich erases current reference to a client session; otherwise pass a unique identifier to store a new client session reference
function User:setSession(email, uid)
    assert(User.exists(self, email), "could not assign session to missing user")
    self:run(
        "update '%s' set %s = '%s' where %s = '%s'",
        self.table, self.column3, tostring(uid or "null")
    )
end


function User:purge(email)
    local valid_authorities = {}
    for authority_name in Authority.get(email):gmatch("[^%s;]+") do
        if Authority.exists(self, authority_name) then
            table.insert(valid_authorities, authority_name)
        end
    end
    Authority.set(self, email, valid_authorities)
end


function User:hasPermission(user_email, permission_identifier)
    if Authority.exists(self, permission_identifier) then
        for authority_name in User.get(self, user_email):gmatch("[^%s;]+") do
            if Authority.hasPermission(self, authority_name, permission_identifier) then
                return true
            end
        end
    end
    return false
end


function User:addPermission()
    error "user not allowed to add permission to authority"
end


function User:removePermission()
    error "user not allowed to remove permission from authority"
end


function User:hasAuthority(user_email, authority_identifier)
    for authority_name in (User.get(self, user_email) or ""):gmatch("[^%s;]+") do
        if authority_identifier == authority_name
        and permission_groups:exists(authority_name)
        then
            return true
        end
    end
    return false
end


function User:addAuthority(user_email, authority_identifier)
    User.set(self, user_email, (User.get(self, user_email) or "").." "..authority_identifier..";")
end


function User:removeAuthority(user_email, authority_identifier)
    local authorities = {}
    for authority_name in (User.get(self, user_email) or ""):gmatch("[^%s;]+") do
        if authority_identifier == authority_name then
            table.insert(authorities, authority_name)
        end
    end
    if getn(authorities) < 1 then
        authorities = nil -- causes deletion of entire user
    end
    User.set(self, user_email, authorities)
end


return User
