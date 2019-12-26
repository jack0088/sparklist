local util = dofile "utilities.lua"
local isfile = util.isfile
local modifiedat = util.modifiedat
util = nil

local _require = require
local hotswap = {
    registry = {},
    interval = 1 -- trigger interval in seconds
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


function require(resource, force_reload) -- override standard Lua function!
    if type(package.loaded[resource]) == "nil" or not force_reload then
        local file_path = url(resource)
        if file_path then
            hotswap.registry[resource] = {
                url = file_path,
                timestamp = modifiedat(file_path)
            }
        end
        return assert(_require(resource))
    end
    local success, message = pcall(dofile, hotswap.registry[resource].url)
    if success and type(message) ~= "nil" then
        -- migrate current state from absolete module to the new loaded one
        local absolete_module = package.loaded[resource]
        local new_module = message
        local stateless = true
        if type(absolete_module) == "table" and type(new_module) == "table" then
            local cache_state = new_module.hotswap or absolete_module.hotswap -- always use the latest migration function
            if type(cache_state) == "function" then
                local state_stack = cache_state(absolete_module)
                if type(state_stack) == "table" then
                    stateless = false
                    for k, v in pairs(state_stack) do
                        new_module[k] = v
                    end
                end
            end
        end
        absolete_module = new_module -- update the module
        print(string.format("%s %s hot-swap of module '%s'",
            os.date("%d.%m.%Y %H:%M:%S"),
            stateless and "stateless" or "stateful",
            hotswap.registry[resource].url
        ))
        return message
    end
end


function hotswap:onEnterFrame() -- xors plugin hook
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


return hotswap
