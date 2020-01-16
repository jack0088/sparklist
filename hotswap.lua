-- 2019 (c) kontakt@herrsch.de

local _require = require
local _ipairs = ipairs
local _pairs = pairs
local _type = type

local INDEX = function(t, k) return getmetatable(t).__swap.value[k] end
local NEWINDEX = function(t, k, v) getmetatable(t).__swap.value[k] = v end
local CALL = function(t, ...) return getmetatable(t).__swap.value(...) end

local utilities = {} -- placeholder, see monkeypatch below

aquire = setmetatable(
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
                return self.package_loaded[module]
            end
            return getmetatable(self).__new(self, module)
        end;

        __new = function(self, module)
            local proxy = getmetatable(self)
            local mname, mpath, mvalue = proxy:__heap(module)
            if not mname or not mpath then
                print(string.format(
                    "%s module '%s' could not be loaded\n%s",
                    os.date("%d.%m.%Y %H:%M:%S"),
                    module,
                    mvalue
                ))
                return self.package_loaded[module] -- if anything
            end
            if type(mvalue) ~= "table" and type(mvalue) ~= "function" then
                self.package_loaded[mname] = mvalue
                return mvalue
            end
            self.package_loaded[mname] = setmetatable({}, {
                __index = type(mvalue) == "table" and INDEX or nil,
                __newindex = type(mvalue) == "table" and NEWINDEX or nil,
                __call = (type(mvalue) == "function" or (type(mvalue) == "table" and mvalue.new)) and CALL or nil,
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
            return self.package_loaded[mname]
        end;

        __update = function(self, proxy)
            local timestamp = utilities.modifiedat(proxy.__swap.path)
            if proxy.__swap.timestamp ~= timestamp then
                local mname, mpath, mvalue = self:__heap(proxy.__swap.name)
                if type(proxy.__swap.value) ~= type(mvalue) then
                    print(string.format(
                        "%s can't hot-reload module '%s' because its type changed from '%s' to '%s' during runtime (please restart the server)",
                        os.date("%d.%m.%Y %H:%M:%S"),
                        mname,
                        type(proxy.__swap.value),
                        type(mvalue)
                    ))
                    -- TODO? support reloading with another retunvalue as the existing one?
                else
                    proxy.__swap.value = mvalue
                    proxy.__swap.timestamp = timestamp
                    print(string.format(
                        "%s module '%s' has been hot-reloaded",
                        os.date("%d.%m.%Y %H:%M:%S"),
                        mname
                    ))
                    -- TODO? each hotswappable object should have a :hotswap method for transfering state or re-instanciating itself
                end
            end
        end;

        __heap = function(self, module)
            local path = self:__url(module)
            assert(type(path) == "string", "can't find module '"..module.."'")
            local ok, msg = pcall(dofile, path)
            if ok then return module, path, msg end
            return nil, nil, msg
        end;

        __url = function(self, resource)
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

-- function require(module)
--     aquire.package_loaded[module] = nil
--     return _require(module)
-- end


-- local a = aquire "_tests.doublerequire"
-- local b = aquire "_tests.doublerequire"
-- local c = a


-- local term
-- local count = 0
-- while true do
--     if not term or term < os.time() then
--         count = count + 1
--         term = os.time() + 1
--         aquire:run()
--         c(count.."x hello world")
--     end
-- end



do
    -- monkeypatch to convert utilities module into hot-swappable object
    -- 1. load the real, working methods from the utilities module
    -- 2. at this point we can actually use aquire() to its full extent
    -- 3. update the entire utilities module by aquiring it, which makes it hot-reload-able
    utilities = dofile "utilities.lua"
    utilities = aquire "utilities"
end


return aquire
