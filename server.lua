-- 2019 (c) kontakt@herrsch.de

package.path = "./?/init.lua;"..package.path -- Lua <= 5.1

require "log"

local hotswap = require "hotswap"
local server = require "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = {
        hotswap, -- upddates via :onEnterFrame
        hotswap "dispatcher"
    }
}:run()
