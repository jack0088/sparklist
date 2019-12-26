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
        return _require(resource)
    end
    local success, message = pcall(dofile, hotswap.registry[resource].url)
    if success and type(message) ~= "nil" then
        print(string.format("%s '%s' has been hot-swapped!", os.date("%d.%m.%Y %H:%M:%S"), hotswap.registry[resource].url))
        package.loaded[resource] = message
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
