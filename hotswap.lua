-- 2019 (c) kontakt@herrsch.de

-- NOTE Be careful with this code in production as it's very expensive in terms of CPU ressources!
-- Its first bottleneck is the file modfification observer (a shell script)
-- and its second bottleneck is the recursive, deep-traversing routine of _G and all available upvalues (for updating pointers)

-- NOTE Always think about preserving state of table members when hot-reloading packages
-- use <table>:hotswap() method to provide the members that need to be preserved

-- NOTE be mindful with class instances as `local foobar = require "foobar"()` will not be swapped because this is its very own copy of the original (hotswappable) module and is not tracked anymore
-- one workaround is to re-save the file that contains the call to make the module instance, in this case the file gets hot-swapped as well and the creation of the class instance will be re-triggered as well...

local util = dofile "utilities.lua"
local isfile = util.isfile
local modifiedat = util.modifiedat
util = nil

local _require = require

local hotswap = {
    registry = {},
    interval = 3 -- trigger interval in seconds
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
        print(string.format(
            "%s module '%s' has been registred for hot-reload",
            os.date("%d.%m.%Y %H:%M:%S"),
            resource
        ))
        return true
    end
    return false
end


local function rereference(absolete, new, namespace, whitelist)
    if type(whitelist) ~= "table" then whitelist = {} end
    if type(namespace) == "table" then
        whitelist[namespace] = true -- mark as visited
        for name, value in pairs(namespace) do
            if value == absolete then
                namespace[name] = new
                print(string.format(
                    "%s global property '%s' has been re-referenced",
                    os.date("%d.%m.%Y %H:%M:%S"),
                    name
                ))
            elseif type(value) == "table" and not whitelist[value] then
                rereference(absolete, new, value, whitelist)
            end
        end
    else
        local thread = 1
        while debug.getinfo(thread) ~= nil do
            local index, name, value = 0, nil, nil
            repeat
                index = index + 1
                name, value = debug.getlocal(thread, index)
                if name ~= nil and name ~= "absolete" and name ~= "new" then
                    if value == absolete then
                        if debug.setlocal(thread, index, new) == name then
                            print(string.format(
                                "%s local upvalue '%s' has been re-referenced",
                                os.date("%d.%m.%Y %H:%M:%S"),
                                name
                            ))
                        end
                    elseif type(value) == "table" and not whitelist[value] then
                        rereference(absolete, new, value, whitelist)
                    end
                end
            until not name
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
                    for k, v in pairs(state_stack) do -- TODO make this multi-level!!! because top level might only hold a few values that should be overriden, the others might remain as initiated..
                        message[k] = v
                    end
                end
            end
        end
        print(string.format(
            "%s module '%s' has been hot-reloaded %s",
            os.date("%d.%m.%Y %H:%M:%S"),
            hotswap.registry[resource].url,
            state_message
        ))
        rereference(package.loaded[resource], message) -- update module references of local upvalues
        rereference(package.loaded[resource], message, _G) -- update module references of globals
        package.loaded[resource] = message -- update the absolete package
        return message
    end
    if not success and message ~= nil then
        print(debug.traceback(string.format(
            "%s failed to hot-reload module '%s'\nerror message: %s",
            os.date("%d.%m.%Y %H:%M:%S"),
            resource,
            message
        )))
    end
end


function hotswap:run() -- call on each frame, periodically or via a interface trigger
    for resource, cache in pairs(self.registry) do
        local timestamp = modifiedat(cache.url)
        if cache.timestamp ~= timestamp then
            cache.timestamp = timestamp
            require(resource, true)
        end
    end
end


function hotswap:onEnterFrame()
    if not self.timeout or self.timeout < os.time() then
        self.timeout = os.time() + self.interval
        self:run()
    end
end


for resource in pairs(package.loaded) do -- find all modules already loaded and register them
    register(resource)
end


return hotswap
