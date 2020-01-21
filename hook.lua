local hotload = require "hotload"

return {
    hotload, -- run watcher via :onEnterFrame
    hotload "connection",
    hotload "dispatcher"
}
