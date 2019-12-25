local dom = require "dom"

local css = "a {color: red; background: yellow; line-height: 20px;}"

local page = dom{
    dom["!doctype"] "html",
    dom.html{
        dom.header{
            dom.title "russische singles in deutschland",
            dom.meta{charset = "utf-8"},
            dom.style{type = "text/css", innerHTML = css}
        },
        dom.body{
            dom.button{innerHTML = "SwoopIn", id="swooplogin"},
            dom.script{src = "https://app.swoopnow.com/swoop.js"},
            dom.script "Swoop.init('wb_Z3T9m51uQnm4lH0QGJU8AA'); document.getElementById('swooplogin').addEventListener('click', function(){ Swoop.open('login'); console.log('login using swoopjs...'); });",
            dom.p "show some user pictures here",
            dom.p{
                dom.a{innerHTML = "login with instagram", href="/auth/instagram"},
                dom.br(),
                dom.a{innerHTML = "login with facebook", href="/auth/facebook"},
                dom.br(),
                dom.a{innerHTML = "login with twitter", href="/auth/twitter"}
            },
            dom.footer "<i>copyright and other stuff down here</i>"
        }
    }
}

return function()
    return page.htmlsource
end