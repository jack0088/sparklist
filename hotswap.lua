-- 2020 (c) kontakt@herrsch.de

local _require = require
local _ipairs = ipairs
local _pairs = pairs
local _type = type

local INDEX = function(t, k) return getmetatable(t).__swap.value[k] end
local NEWINDEX = function(t, k, v) getmetatable(t).__swap.value[k] = v end
local CALL = function(t, ...) return getmetatable(t).__swap.value(...) end
local TYPE = function(t) return type(getmetatable(t).__swap.value) end
local IPAIRS = function(t) return ipairs(getmetatable(t).__swap.value) end
local PAIRS = function(t) return pairs(getmetatable(t).__swap.value) end

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
            package.loaded[module] = nil -- clean require registry
            if self.package_loaded[module] then
                local value = getmetatable(self.package_loaded[module]).__swap.value
                if type(value) ~= "table" and type(value) ~= "function" then
                    return value
                end
                return self.package_loaded[module]
            end
            return getmetatable(self).__create(self, module)
        end;

        __create = function(self, module)
            local mname, mpath, mvalue = getmetatable(self):__heap(module)
            if not mname or not mpath then
                print(string.format(
                    "%s module '%s' could not be loaded\n%s",
                    os.date("%d.%m.%Y %H:%M:%S"),
                    module,
                    mvalue
                ))
                return nil
            end
            self.package_loaded[mname] = setmetatable({}, {
                __index = type(mvalue) == "table" and INDEX or nil,
                __newindex = type(mvalue) == "table" and NEWINDEX or nil,
                __call = (type(mvalue) == "function" or (type(mvalue) == "table" and mvalue.new)) and CALL or nil,
                __type = TYPE,
                __ipairs = IPAIRS,
                __pairs = PAIRS,
                __swap = {
                    name = mname,
                    path = mpath,
                    value = mvalue,
                    timestamp = utilities.modifiedat(mpath)
                }
            })
            print(string.format(
                "%s module '%s' has been required and registred for hot-reload",
                os.date("%d.%m.%Y %H:%M:%S"),
                mname
            ))
            return self(module) -- __call()
        end;

        __update = function(self, proxy)
            local timestamp = utilities.modifiedat(proxy.__swap.path)
            if proxy.__swap.timestamp ~= timestamp then
                local mname, mpath, mvalue = self:__heap(proxy.__swap.name)
                proxy.__swap.value = mvalue
                proxy.__swap.timestamp = timestamp
                print(string.format(
                    "%s module '%s' has been hot-reloaded",
                    os.date("%d.%m.%Y %H:%M:%S"),
                    mname
                ))
                -- TODO? each hotswappable object should have a :hotswap function for transfering state its to the swapped object?
            end
        end;

        __heap = function(self, module)
            local path = self:__path(module)
            assert(type(path) == "string", "can't find module '"..module.."'")
            local ok, msg = pcall(dofile, path)
            if ok then return module, path, msg end
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
    if hotload and hotload.package_loaded[module] then
        return hotload(module)
    end
    return _require(module)
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


function iparis(obj)
    local proxy = getmetatable(obj)
    if proxy and type(proxy.__ipairs) == "function" then
        return proxy.__ipairs(obj)
    end
    return _ipairs(obj)
end


function pairs(obj)
    local proxy = getmetatable(obj)
    if proxy and type(proxy.__pairs) == "function" then
        return proxy.__pairs(obj)
    end
    return _pairs(obj)
end


return hotload
