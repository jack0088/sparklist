-- 2020 (c) kontakt@herrsch.de

local _require = require
local _ipairs = ipairs
local _pairs = pairs
local _type = type
local _getn = table.getn

local INDEX = function(t, k) return getmetatable(t).__swap.value[k] end
local NEWINDEX = function(t, k, v) getmetatable(t).__swap.value[k] = v end
local CALL = function(t, ...) return getmetatable(t).__swap.value(...) end
local TYPE = function(t) return _type(getmetatable(t).__swap.value) end
local IPAIRS = function(t) return _ipairs(getmetatable(t).__swap.value) end
local PAIRS = function(t) return _pairs(getmetatable(t).__swap.value) end
local LEN = function(t) return _getn(getmetatable(t).__swap.value) end

local utilities = {} -- placeholder, see monkeypatch below

hotload = setmetatable(
    {
        package_loaded = {};
        reload_interval = 3;

        run = function(self)
            for module, value in pairs(self.package_loaded) do
                local proxy = getmetatable(value)
                if type(proxy) == "table" then -- is a hot-swappable object
                    local this = getmetatable(self)
                    this:__update(proxy)
                end
            end
        end;

        onEnterFrame = function(self)
            if not self.reload_timeout or self.reload_timeout < os.time() then
                self.reload_timeout = os.time() + self.reload_interval
                self:run()
            end
        end
    },
    {
        __call = function(self, module)
            assert(
                not package.loaded[module],
                "module '"..tostring(module).."' can't be registred for hot-reload as it has already been loaded traditionally via require()"
            )
            if self.package_loaded[module] then
                local value = getmetatable(self.package_loaded[module]).__swap.value
                if type(value) == "function" or type(value) == "table" then
                    return self.package_loaded[module] -- via proxy wrapper
                end
                return value
            end
            return getmetatable(self).__create(self, module)
        end;

        __create = function(self, module)
            local mname, mpath, mvalue = getmetatable(self):__heap(module)
            if not mname or not mpath then
                error(string.format(
                    "module '%s' could neither be loaded nor registred (seems having errors) %s",
                    module,
                    type(mvalue) == "nil" and "because it returns nil" or "\n"..tostring(mvalue)
                ))
                return nil
            end
            self.package_loaded[mname] = setmetatable({}, {
                __index = type(mvalue) == "table" and INDEX or nil,
                __newindex = type(mvalue) == "table" and NEWINDEX or nil,
                __call = (type(mvalue) == "function" or type(mvalue) == "table") and CALL or nil,
                __ipairs = type(mvalue) == "table" and IPAIRS or nil,
                __pairs = type(mvalue) == "table" and PAIRS or nil,
                __len = type(mvalue) == "table" and LEN or nil,
                __type = TYPE,
                __swap = {
                    name = mname,
                    path = mpath,
                    value = mvalue,
                    timestamp = utilities.modifiedat(mpath)
                }
            })
            print(string.format("module '%s' has been loaded and registred for hot-reload", mname))
            return getmetatable(self).__call(self, module)
        end;

        __update = function(self, proxy)
            local timestamp = utilities.modifiedat(proxy.__swap.path)
            if proxy.__swap.timestamp ~= timestamp then
                local mname, mpath, mvalue = self:__heap(proxy.__swap.name)
                if mname and mpath and mvalue then
                    proxy.__swap.value = mvalue
                    proxy.__swap.timestamp = timestamp
                    print(string.format("module '%s' has been hot-reloaded", mname))
                    -- TODO? preserve state of hotswappable objects
                    -- by providing :hotswap class method for transfering state
                    -- onto the swapped objects?
                else
                    print(string.format("module '%s' could not be hot-re-loaded\n%s", module, mvalue))
                end
            end
        end;

        __heap = function(self, module)
            local path = self:__path(module)
            assert(type(path) == "string", "can't find module '"..module.."'")
            local ok, msg = pcall(dofile, path)
            if ok == true and msg ~= nil then
                return module, path, msg
            end
            return nil, nil, msg
        end;

        __path = function(self, resource)
            local file_path = resource:gsub("%.", "/")
            if file_path:sub(1, 1) == "/" then file_path = "."..file_path end
            if file_path:sub(-4) ~= ".lua" then file_path = file_path..".lua" end
            if not utilities.isfile(file_path) then
                file_path = file_path:sub(1, -4).."init.lua"
                if not utilities.isfile(file_path) then
                    file_path = nil
                end
            end
            return file_path
        end
    }
)


do
    -- monkeypatch to convert utilities module into hot-swappable object
    -- 1. load the real, working methods from the utilities module
    -- 2. at this point we can actually use hotload() to its full extent
    -- 3. update the entire utilities module by aquiring it, which makes it hot-reload-able
    utilities = dofile "utilities.lua"
    utilities = hotload "utilities"
end


function require(module)
    return (type(hotload) == "table" and hotload.package_loaded[module]) and hotload(module) or _require(module)
end


function type(obj)
    local proxy = getmetatable(obj)
    if proxy and proxy.__type then
        if _type(proxy.__type) == "string" then
            return proxy.__type
        elseif _type(proxy.__type) == "function" then
            return proxy.__type(obj)
        end
    end
    return _type(obj)
end


function ipairs(obj)
    local proxy = getmetatable(obj)
    if proxy and _type(proxy.__ipairs) == "function" then
        return proxy.__ipairs(obj)
    end
    return _ipairs(obj)
end


function pairs(obj)
    local proxy = getmetatable(obj)
    if proxy and _type(proxy.__pairs) == "function" then
        return proxy.__pairs(obj)
    end
    return _pairs(obj)
end


function table.getn(obj)
    local proxy = getmetatable(obj)
    if proxy and _type(proxy.__len) == "function" then
        return proxy.__len(obj)
    end
    return _getn(obj)
end


return hotload
