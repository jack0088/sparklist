-- 2019 (c) kontakt@herrsch.de

package.path = "./?/init.lua;"..package.path -- Lua <= 5.1

require "log"

local server = require "xors"{
    port = 80,
    timeout = 0.01,
    backlog = 100,
	plugins = require "plugins"
}:run()
