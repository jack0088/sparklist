-- 2020 (c) kontakt@herrsch.de


local getn = table.getn or function(t) return #t end -- Lua > 5.1 idom
local hotload = require "hotload"
local class = hotload "class"
local permission_keys = hotload "permission"()
local KVStorage = hotload "kvstorage"
local Authority = class(KVStorage)


-- @name (optional string) name of the authority to act on e.g. "admin", "visitor", "author"
-- @permissions (optional string or table) list of (default) permission names to assign to that authority; with CSV syntax, e.g. "read_posts; email.options.send; blog-create-draft*;" and is only useful to pass for yet non-existing authorities
function Authority:new(name, permissions)
    KVStorage.new(self, "authorities", "name", "permissions", "db/acl.db")
    if type(name) == "string" and #name > 0 then
        if (type(permissions) == "table" and getn(permissions) > 0)
        or (type(permissions) == "string" and #permissions > 1)
        then
            Authority.set(name, permissions)
        end
        self.identifier = name
        Authority.purge(self.identifier)
    end
end


function Authority:get_identifier()
    return self.__identifier
end


function Authority:set_identifier(name)
    assert(Authority.exists(name), "authority named '"..name.."' does not exist yet")
    self.__identifier = name
    local wrappable_methods = {
        "create",
        "exists",
        "get",
        "set",
        "hasPermission",
        "addPermission",
        "removePermission"
    }
    for _, method in ipairs(wrappable_methods) do
        -- bind/wrap class methods so that we don't need to pass the autority identifier anymore
        self[method] = function(...) return self[method](self.identifier, ...) end
    end
end


function Authority:exists(name)
    return name ~= nil and not not KVStorage.exists(self, name)
end


-- @name (required string)
-- @permissions (required string or table) list of permission names to add to the authority with @name
function Authority:set(name, permissions)
    -- convert string into table
    if type(permissions) == "string" then
        local list = {}
        for name in permissions:gmatch("[^%s;]+") do
            table.insert(list, name)
        end
        permissions = list
    end
    -- order permission id's and remove duplicates
    if type(permissions) == "table" then
        table.sort(permissions)
        for n = getn(permissions), 1, -1 do
            if permissions[n] == permissions[n - 1] then
                -- NOTE we could also filter out non-existent permission keys (although this doesn't add any advantages)
                -- with additional condition of `or not permission_keys:exists(permissions[n])`
                -- however, then we would need to override the User.set method with roughly same code as here,
                -- plus a check for authority_keys:exists(authorities[n])
                table.remove(permissions, n)
            end
        end
    end
    -- convert table back into a string with CSV syntax and save into db
    KVStorage.set(name, table.concat(permissions, "; ")..";")
end


-- clean permission name in db column to only contain permissions that really exist and are valid
-- @name (require string)
function Authority:purge(name)
    local valid_permissions = {}
    for permission_name in Authority.get(name):gmatch("[^%s;]+") do
        if permission_keys:exists(permission_name) then
            table.insert(valid_permissions, permission_name)
        end
    end
    Authority.set(name, valid_permissions)
end


-- @authority_name (required string) name of the authority to check permissions on
-- @permission_identifier (required string or number) uuid or name of the permission key you want to verify; most often this will be a string name of a permission key
function Authority:hasPermission(authority_name, permission_identifier)
    if permission_keys:exists(permission_identifier) then
        if type(tonumber(permission_identifier)) ~= "number" then
            permission_identifier = permission_keys:getUUID(permission_identifier)
        end
        local permissions_list, matching_permission = {}
        for permission_name in Authority.get(authority_name):gmatch("[^%s;]+") do
            table.insert(permissions_list, permission_name)
            local uid = permission_keys:getUUID(permission_name)
            if uid == permission_identifier then
                matching_permission = uid
            end
        end
        if type(tonumber(matching_permission)) == "number" then
            return true, permissions_list, matching_permission
        end
    end
    return false
end


function Authority:addPermission(authority_name, permission_identifier)
    assert(Authority.hasPermission(authority_name, permission_identifier), string.format(
        "could not add permission '%s' to authority '%s' because such permission does not exist",
        permission_identifier,
        authority_name
    ))
    Authority.set(authority_name, (Authority.get(authority_name) or "").." "..permission_identifier..";")
end


function Authority:removePermission(authority_name, permission_identifier)
    local exists, permissions, match = Authority.hasPermission(authority_name, permission_identifier)
    if exists then
        table.remove(permissions, match)
        Authority.set(authority_name, permissions)
    end
end


return Authority
