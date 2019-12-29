-- 2019 (c) kontakt@herrsch.de

package.path = "./?/init.lua;"..package.path -- Lua <= 5.1

local hotswap = require "hotswap"
local router = require "api"
local server = require "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = {hotswap, router}
}:run()
