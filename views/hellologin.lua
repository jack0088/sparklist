local http = require "socket.http"
local dom = require "dom"

return function(email)
    local message = "sorry fellow, i dont know you - keep out of here!"
    if type(email) == "string" and #email > 0 then message = "dear friend "..email..", oh my well known friend. happilly welcome back :)" end

    return dom{
        dom["!doctype"] "html",
        dom.html{
            dom.header{
                dom.title "rumantika logged-in",
                dom.meta{charset = "utf-8"},
            },
            dom.body{
                dom.p(message)
            }
        }
    }.sourcecode
end