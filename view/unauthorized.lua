local hotload = require "hotload"
local dom = hotload "dom"

return function(previous_url)
    return dom{
        dom["!doctype"] "html",
        dom.html{
            dom.header{
                dom.title "log-in, please",
                dom.meta{charset = "utf-8"},
                dom.script{src = "https://app.swoopnow.com/swoop.js"}
            },
            dom.body{
                dom.h1 "You are not logged-in.",
                dom.p(string.format("You came from '%s'", tostring(previous_url))),
                dom.button{innerHTML = "Login, please.", id="swoop"},
                dom.script [[
                    Swoop.init('wb_VVknxPn8YkxMipKjFWEehw');
                    document.getElementById('swoop').addEventListener('click', function() {
                        Swoop.open('login');
                    });
                ]],
            }
        }
    }.sourcecode
end
