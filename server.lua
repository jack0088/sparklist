-- 2019 (c) kontakt@herrsch.de

require "xors.logger"

local search = require "xors.searchpath"
search("./xors/?.lua")
search("./xors/?/init.lua")

local hotload = require "hotload"
local server = hotload "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = hotload "hooks"
}:run()
