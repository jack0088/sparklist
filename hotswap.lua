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


local function update_upvalue_references(old_reference, new_reference)
    local upvalues = {}
    local failures = 0
    local thread = 0
    while true do
        thread = thread + 1
        local index = 0
        if debug.getinfo(thread) == nil then break end
        while true do
            index = index + 1
            local name, value = debug.getlocal(thread, index)
            if name == nil then
                if index == 1 then failures = failures + 1 end
                break
            else
                print(thread..","..index, name, value, ":", old_reference, new_reference)
                if name ~= "old_reference" and name ~= "new_reference" and value == old_reference then
                    print(thread, index, name)
                    print(debug.setlocal(thread, index, new_reference), "<--- should equal "..name)
                end
            end
        end
        if failures > 1 then break end
    end
    return upvalues
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
        -- migrate current state from absolete module to the new loaded one
        -- NOTE xors plugins can use a hook :hotswap() to provide a table of their states
        local state_message = "stateless"
        local current_time = os.date("%d.%m.%Y %H:%M:%S")
        if type(package.loaded[resource]) == "table" and type(message) == "table" then
            local cache_state = message.hotswap or package.loaded[resource].hotswap -- always use the latest migration function
            if type(cache_state) == "function" then
                local state_stack = cache_state(package.loaded[resource]) -- with self reference
                if type(state_stack) == "table" then
                    state_message = "stateful"
                    for k, v in pairs(state_stack) do
                        message[k] = v
                    end
                end
            end
        end

        -- update module references of local upvalues
        update_upvalue_references(package.loaded[resource], message)

        -- update the absolete module
        package.loaded[resource] = message
        print(string.format("%s %s hot-swap of module '%s'",
            current_time,
            state_message,
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
