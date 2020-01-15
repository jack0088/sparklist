-- 2019 (c) kontakt@herrsch.de

package.path = "./?/init.lua;"..package.path -- Lua <= 5.1

require "log"

local server = require "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = {
        require "dispatcher"
    }
}:run()
