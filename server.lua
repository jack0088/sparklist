--[[

Define your routes and server configuration here...

Any route should return true on successful handling and false on failing.
Any route that returns nil (void) will fall-through to next possible match.

2019 (c) kontakt@herrsch.de

--]]

local hotswap = require "hotswap"
test = {}
test.foobar = require "foobar"
-- test = require "foobar"

while true do
    hotswap:onEnterFrame()
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
