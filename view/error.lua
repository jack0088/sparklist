local hotload = require "hotload"
local dom = hotload "dom"

return function(path, method, status, message)
    assert(type(path) == "string", "view is missing parameters")
    return dom{
        dom["!doctype"] "html",
        dom.html{
            dom.header{
                dom.title(tostring(status or "error")),
                dom.meta{charset = "utf-8"}
            },
            dom.body{
                dom.h1 "server could not respond to your request",
                dom.div(string.format("requested url: %s", path)),
                method and dom.div(string.format("request method: %s", method)),
                status and dom.div(string.format("response status code: %s", status)),
                message and dom.div(string.format("response message: %s", message))
            }
        }
    }.htmlsource
end