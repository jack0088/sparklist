-- 2019 (c) kontakt@herrsch.de

package.path = "./?/init.lua;"..package.path -- Lua <= 5.1

require "logger"
local hotload = require "hotload"

local server = hotload "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = hotload "hook"
}:run()
