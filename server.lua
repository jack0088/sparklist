-- 2019 (c) kontakt@herrsch.de

local hotload = require "xors.hotload"
local server = hotload "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = hotload "hook"
}:run()
