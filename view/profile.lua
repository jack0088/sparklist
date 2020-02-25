local hotload = require "xors.hotload"
local dom = hotload "xors.dom"

return function(email, url)
    local message = "sorry fellow, i dont know you."
    if email then
        message = "dear friend, i know your email &lt;"..email.."&gt;. well hello world :)"
    end
    return dom{
        dom["!doctype"] "html",
        dom.html{
            dom.header{
                dom.title "profile page",
                dom.meta{charset = "utf-8"},
            },
            dom.body{
                dom.p(message),
                dom.p(string.format("here's the url you originally requested: '%s'", tostring(url)))
            }
        }
    }.sourcecode
end
