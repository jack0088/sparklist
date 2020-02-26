-- 2019 (c) kontakt@herrsch.de

local searchpath = require "xors.searchpath"
searchpath("./xors/?.lua")
searchpath("./xors/?/init.lua")

local hotload = require "hotload"
hotload "logger"

local server = hotload "xors"{
    port = 80,
    timeout = 0.1,
    backlog = 100,
	plugins = hotload "hook"
}:run()
