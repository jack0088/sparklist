-- this library allows you to hot-reload code in your project
-- NOTE this module should be your first module to require in your project!
-- as it extends require() in regard that it enriches every registred module in package.loaded with additional information
-- about modification time and checksum of the file contents at the time it was last (re)loaded,
-- as well as the modules real file path
-- this way we can periodically compare loaded module files and hot-reload them into memory whenever possible

local platform = require "sysutils".os
local isfile = require "sysutils".isfile
local modifiedat = require "sysutils".modifiedat
local checksum = require "sysutils".checksum
local _require = require
local hotswap = {} -- registry for additional information about the module


-- lazy convert lua module names into valid file paths
-- e.g. require "foo.bar.baz" results in a file path of "foo/bar/baz.lua"
-- this solution only works for "?.lua" files, not compiled libraries
-- NOTE we could build our own require() replacement with a package.path searcher & co - similar to how lua does it,
-- but why struggle if all we want is requiring files relative to the project, also them being only lua modules...
-- NOTE function only works on unix based platforms with forwar-slashes in path strings
-- but could be expanded to work with backslashes as well
local function sourcepath(resource)
    local filepath
    if platform("darwin") or platform("linux") then
        filepath = resource:gsub("%.", "/")
        if filepath:sub(1, 1) == "/" then filepath = "."..filepath end
        if filepath:sub(-4) ~= ".lua" then filepath = filepath..".lua" end
        if not isfile(filepath) then filepath = nil end
    end
    return filepath
end


local function sourceinfo(resource, registry)
    if not registry[resource] then registry[resource] = {} end
    registry[resource].url = registry[resource].url or sourcepath(resource)
    if not registry[resource].url then
        registry[resource] = nil
        return
    end
    registry[resource].time = modifiedat(registry[resource].url)
    registry[resource].checksum = checksum(registry[resource].url)
end


function require(resource, forcereplace)
    local message
    if type(package.loaded[resource]) == "nil" or not forcereplace then
        message = _require(resource)
    else
        -- siliently ignore the errors when hot-reloading
        local url = sourcepath(resource)
        if not url then return nil end
        local chunk, err, success = loadfile(url)
        if not chunk or err then return nil end
        success, message = pcall(chunk)
        if success and type(message) ~= "nil" then
            package.loaded[resource] = message
            message = package.loaded[resource]
            print(string.format("hot-swapped '%s'", resource))
        end
    end
    sourceinfo(resource, hotswap) -- additional information about the module file
    return message
end


return function() -- watch for file changes on already required modules
    for loaded_resource, existing_module in pairs(hotswap) do
        if existing_module.time ~= modifiedat(existing_module.url)
        or existing_module.checksum ~= checksum(existing_module.url)
        then
            require(loaded_resource, true)
        end
    end
end
