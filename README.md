# xors & sparklist.io

This project is primarily all about the creation of a web server written entirely in vanilla Lua, however, unlike [Lapis](https://leafo.net/lapis) it **doesn't** rely on Nginx, OpenResty or Apache as its host-/wrapping system. The working title for this Lua HTTP server is `xors`.

Xors only depends on [LuaSocket](http://w3.impa.br/~diego/software/luasocket) and uses native Lua coroutines for its asynchronous/multithreaded event loop. Xors tries to be minimalistic and thus only supports HTTP 1.1 without TLS. You can add SSL security, e.g. by hiding Xors behind a SSL proxy like [CloudFlare](https://www.cloudflare.com). However, [LuaSec](https://github.com/brunoos/luasec) is required for user-authentication and -login functionality because [SwoopJS](https://swoopnow.com) relys on HTTPS connections from the server. All data is stored across various [SQLite3](https://www.sqlite.org) databases, so you will need to install [LuaSQL](https://keplerproject.github.io/luasql) as well.

[Sparklist](https://sparklist.io) is the first online service that uses the Xors HTTP web server. It's a platform for sharing \[business\] ideas and making ones that don't exist yet. The site combines elements from different services, like Twitter, Reddit, StakcOverflow, HackerOne and more.
