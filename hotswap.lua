local util = require "utilities"
local _require = require
local registry = {}
local trigger_interval, timeout = 1 -- seconds


local function url(resource)
    local file_path = resource:gsub("%.", "/")
    if file_path:sub(1, 1) == "/" then file_path = "."..file_path end
    if file_path:sub(-4) ~= ".lua" then file_path = file_path..".lua" end
    if not util.isfile(file_path) then
        file_path = file_path:sub(1, -4).."init.lua"
        if not util.isfile(file_path) then
            file_path = nil
        end
    end
    return file_path
end


function require(resource, force_reload)
    if type(package.loaded[resource]) == "nil" or not force_reload then
        local file_path = url(resource)
        if file_path then
            registry[resource] = {
                url = file_path,
                timestamp = util.modifiedat(file_path)
            }
        end
        return _require(resource)
    end
    local success, message = pcall(dofile, registry[resource].url)
    if success and type(message) ~= "nil" then
        print(string.format("hot-swapped '%s'", registry[resource].url))
        package.loaded[resource] = message
        return message
    end
end


return function()
    if not timeout or timeout < os.time() then
        timeout = os.time() + trigger_interval
        for resource, cache in pairs(registry) do
            local timestamp = util.modifiedat(cache.url)
            if cache.timestamp ~= timestamp then
                cache.timestamp = timestamp
                require(resource, true)
            end
        end
    end
end
