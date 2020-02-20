# xors

This project is primarily all about the creation of a HTTP web server written entirely in vanilla [Lua](http://lua.org), however, unlike [Lapis](https://leafo.net/lapis) it **doesn't** rely on [Nginx](http://nginx.com), [OpenResty](http://openresty.org) or [Apache](https://httpd.apache.org/docs/trunk/mod/mod_lua.html) as its host-/wrapping system. The working title for this web server is `xors`.

Xors depends on [Lua >= 5.1](https://www.lua.org/manual/5.1/manual.html) and [LuaSocket](http://w3.impa.br/~diego/software/luasocket) and uses native Lua coroutines for its asynchronous/multithreaded event loop. Xors tries to be minimalistic and thus only supports HTTP/1.1 without TLS. You can add SSL security e.g. by hiding xors behind a SSL proxy like [CloudFlare](https://www.cloudflare.com). Xors uses [SwoopJS](https://swoopnow.com) to authenticate and login users without any passwords and it relys on HTTPS connections from the server, hence [LuaSec](https://github.com/brunoos/luasec) is required anyway, regardless of the reverse proxy. All data is stored across various [SQLite3](https://www.sqlite.org) databases, so you will need to install [LuaSQL](https://keplerproject.github.io/luasql) as well.


#  sparklist.io

[Sparklist](https://sparklist.io) is the first online service that uses the xors HTTP web server. It's a platform for sharing \(business\) ideas and making the ones a reality that don't exist yet. The site combines some elements from different services, like Twitter, Reddit, StackOverflow, HackerOne and more.


All of this is WIP and subject to change...
