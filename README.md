# xors

This project is primarily all about the creation of a HTTP web server written entirely in vanilla [Lua](http://lua.org), however, unlike e.g. [Lapis](https://leafo.net/lapis) it **doesn't** rely on [Nginx](http://nginx.com), [OpenResty](http://openresty.org) or [Apache](https://httpd.apache.org/docs/trunk/mod/mod_lua.html) as its host application. The working title for this web server is `xors`.

Xors depends on [Lua >= 5.1](https://www.lua.org/manual/5.1/manual.html) and [LuaSocket](http://w3.impa.br/~diego/software/luasocket) and uses native Lua coroutines for its asynchronous/multithreaded event loop. Xors tries to be minimalistic and thus only supports HTTP/1.1 without TLS. You can add SSL security e.g. by hiding xors behind a SSL proxy like [CloudFlare](https://www.cloudflare.com). Xors uses [SwoopJS](https://swoopnow.com) to authenticate and login users without any passwords and this library relys on HTTPS connections from the server, hence [LuaSec](https://github.com/brunoos/luasec) is required as well, regardless of a reverse proxy. All data is stored across various [SQLite3](https://www.sqlite.org) databases, so you will need to install it and [LuaSQL](https://keplerproject.github.io/luasql) as well.


#  sparklist.io

[Sparklist](https://sparklist.io) is my first web service that uses the xors HTTP web server, as mentioned above. It's a platform for sharing \(business\) ideas and/or making ones that don't exist yet. The site combines some elements from different services like Twitter, Reddit, StackOverflow, HackerOne and others.


## acknowledgement

All of this is very rudimentary work in progress and subject to change. Nothing of this should be used in production.

**Currently I'm re-writing the passwordless Swoop service integration. The goal is to trigger an authentication check on every client request. The router can ask for different permissions while dispatching and responding to a request which makes things simple to manage.**
