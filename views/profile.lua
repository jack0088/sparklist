local dom = require "dom"

return function(email)
    local message = "sorry fellow, i dont know you."
    if type(email) == "string" and #email > 0 then
        message = "dear friend, i know your email <"..email..">. well hello world :)"
    end
    return dom{
        dom["!doctype"] "html",
        dom.html{
            dom.header{
                dom.title "profile page",
                dom.meta{charset = "utf-8"},
            },
            dom.body{
                dom.p(message)
            }
        }
    }.sourcecode
end
