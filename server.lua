local hotswap = require "hotswap"
require "_tests.lol.foo"

local lfs = require "lfs"
local files = {"hotswap.lua", "_tests/lol/foo.lua", "_tests/lol/test.lua"}
local function lsfroutine()
    if not tt or tt < os.time() then
        tt = os.time() + 1
        for _, path in ipairs(files) do print(path, lfs.attributes(path).modification) end
    end
end

-- seems like hotswap() works performance-wise similar to lsfroutine()
-- so i see no reason to switch from unix plumbing tool to lfs c library

for k, v in pairs(package.loaded) do
    print(k)
end

while true do
    hotswap()
    -- lsfroutine()
end

