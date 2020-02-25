-- 2019 (c) kontakt@herrsch.de

-- fallowing is an example how chunked requests and responses are handled correctly
-- this controller function is actually always wrapped into a coroutine, later inside the dispatcher (who's an instance of the router, so look inside the router to find the wrapping routine)
-- at any point, you can yield this function and let another client be served until continuing this operation on the next frame

-- responses are blocking loops (chunked requests or not) which you can yield anyways by supplying a steram_sink function to the :receiveMessage() method of the response
-- inside that sink you can now process each chunk of the stream (or the whole request message if no Transfer-Encoding: chunkt were used)

-- similar applies to responses - they blocking as well, but when writing only chunk by chunk you can use a while loop for example
-- now, that loop can be yielded as well as you can guess :)

local hotload = require "xors.hotload"
local dt = hotload "xors.datetime"

return function(client)
    print "receiving chunked request (if any):"
    client.request:receiveMessage(function(chunk)
        print("request chunk received:", chunk)
        print "yielded.."
        coroutine.yield(chunk)
    end)
    print("request.message:", client.request.message)

    print "responding with chunked response:"
    client.response.header:set("Date", dt.date())
    client.response.header:set("Content-Type", "text/plain; charset=utf-8")
    client.response.header:set("Transfer-Encoding", "chunked")

    print("-->", client.response.header:get "Transfer-Encoding", client.response.header:get "Transfer-Encoding" == "chunked")
    client.response:sendHeader(200)

    local f, line = io.open("upload/lol.txt", "rb")
    repeat
        line = f:read("*l")
        if line then
            client.response:sendMessage(line.."\n")
            print("response chunk send:", line)
            print "yielded.."
            coroutine.yield(line)
        end
    until not line
    f:close()
    print("response.message:", client.response.message)
    print("done req/res!")

    return client.response:submit()
end
