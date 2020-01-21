local hotload = require "hotload"
local dom = hotload "dom"

local page = dom{
    dom["!doctype"] "html",
    dom.html{
        dom.header{
            dom.title "sparklist.io",
            dom.meta{charset = "utf-8"},
            dom.style{type = "text/css", innerHTML = css}
        },
        dom.body{
            dom.button{innerHTML = "Login with SwoopJS", id="swooplogin"},
            dom.script{src = "https://app.swoopnow.com/swoop.js"},
            dom.script "Swoop.init('wb_VVknxPn8YkxMipKjFWEehw'); document.getElementById('swooplogin').addEventListener('click', function(){Swoop.open('login');});",
            dom.p "show some user pictures here",
            dom.p "some other content over here",
            dom.footer "<i>maybe a copyright 2020-2021 here and other stuff down here</i>"
        }
    }
}

return function()
    return page.htmlsource
end