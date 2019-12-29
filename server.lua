-- 2019 (c) kontakt@herrsch.de


test = {}
test.foobar = require "foobar"
-- test = require "foobar"

local hotswap = require "hotswap"

while true do
    hotswap:run()
    if not ko or ko < os.time() then
        ko = os.time() + .5
        test.foobar:speak()
    end
end


package.path = "./?/init.lua;"..package.path -- Lua <= 5.1

local hotswap = require "hotswap"
local router = require "api"
local server = require "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = {hotswap, router}
}:run()
