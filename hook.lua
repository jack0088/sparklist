-- 2020 (c) kontakt@herrsch.de

package.path = "./?/init.lua;"..package.path -- Lua <= 5.1

require "xors.logger"

local hotload = require "xors.hotload"

return {
    hotload, -- run watcher via :onEnterFrame
    hotload "xors.connection",
    hotload "xors.websocket",
    hotload "dispatcher"
}
