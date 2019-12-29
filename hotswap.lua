-- 2019 (c) kontakt@herrsch.de

-- NOTE Be careful with this code in production as it's very expensive in terms of CPU ressources!
-- Its first bottleneck is the file modfification observer (a shell script)
-- and its second bottleneck is the recursive, deep-traversing routine of _G and all available upvalues (for updating pointers)
-- NOTE Always think about preserving state of table members when hot-reloading packages
-- use <table>:hotswap() method to provide the members that need to be preserved

local util = dofile "utilities.lua"
local isfile = util.isfile
local modifiedat = util.modifiedat
util = nil

local _require = require
local hotswap = {
    registry = {},
    interval = 5 -- trigger interval in seconds
}


local function url(resource)
    local file_path = resource:gsub("%.", "/")
    if file_path:sub(1, 1) == "/" then file_path = "."..file_path end
    if file_path:sub(-4) ~= ".lua" then file_path = file_path..".lua" end
    if not isfile(file_path) then
        file_path = file_path:sub(1, -4).."init.lua"
        if not isfile(file_path) then
            file_path = nil
        end
    end
    return file_path
end


local function register(resource)
    if hotswap.registry[resource] ~= nil then return true end
    local file_path = url(resource)
    if file_path then
        hotswap.registry[resource] = {
            url = file_path,
            timestamp = modifiedat(file_path)
        }
        print(string.format("module '%s' has been registred for hot-reload", resource))
        return true
    end
    return false
end


local function rereference(absolete, new, namespace, whitelist)
    if type(namespace) == "table" then
        --TODO deep traverse; look into metatables as well! BUT not already seen tables!
        
        if whitelist == nil or treated[namespace] == nil then
            for k, v in pairs(namespace) do
                if v == absolete then
                    namespace[k] = new
                elseif type(v) == "table" then
                    -- rereference(absolete, new, v)
                end
            end
        end
    else
        local thread = 1
        while debug.getinfo(thread) ~= nil do
            local index, name, value = 0, nil, nil
            repeat
                index = index + 1
                name, value = debug.getlocal(thread, index)
                if name ~= nil
                and name ~= "absolete"
                and name ~= "new"
                then
                    if value == absolete then
                        if debug.setlocal(thread, index, new) == name then
                            print(string.format(
                                "%s local upvalue '%s' has been re-referenced",
                                os.date("%d.%m.%Y %H:%M:%S"),
                                name
                            ))
                        end
                    elseif type(value) == "table" then
                        rereference(absolete, new, value)
                    end
                end
            until name == nil
            thread = thread + 1
        end
    end
end


function require(resource, force_reload) -- override standard Lua function!
    if type(package.loaded[resource]) == "nil" or not force_reload then
        register(resource)
        return _require(resource)
    end
    local success, message = pcall(dofile, hotswap.registry[resource].url)
    if success and type(message) ~= "nil" then
        -- migrate current state from absolete module to the new loaded one
        -- NOTE xors plugins can use a hook :hotswap() to provide a table of their states to be preserved when hot-reloading the module
        local state_message = "without preserving state"
        if type(package.loaded[resource]) == "table" and type(message) == "table" then
            local cache_state = message.hotswap or package.loaded[resource].hotswap -- always use the latest migration function
            if type(cache_state) == "function" then
                local state_stack = cache_state(package.loaded[resource]) -- with self reference
                if type(state_stack) == "table" then
                    state_message = "statefully"
                    for k, v in pairs(state_stack) do
                        message[k] = v
                    end
                end
            end
        end
        rereference(package.loaded[resource], message, _G) -- update module references of globals
        rereference(package.loaded[resource], message) -- update module references of local upvalues
        package.loaded[resource] = message -- update the absolete package
        print(string.format(
            "%s module '%s' has been hot-reloaded %s",
            os.date("%d.%m.%Y %H:%M:%S"),
            hotswap.registry[resource].url,
            state_message
        ))
        return message
    end
end


function hotswap:run() -- call on each frame, periodically or via a trigger
    if not self.timeout or self.timeout < os.time() then
        self.timeout = os.time() + self.interval
        for resource, cache in pairs(self.registry) do
            local timestamp = modifiedat(cache.url)
            if cache.timestamp ~= timestamp then
                cache.timestamp = timestamp
                require(resource, true)
            end
        end
    end
end


function hotswap:onEnterFrame() -- xors plugin hook
    self:run()
end


for resource in pairs(package.loaded) do -- find all modules already loaded and register them
    register(resource)
end


return hotswap
