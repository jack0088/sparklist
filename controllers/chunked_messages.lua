return function(request, response)
    print "receiving chunked request (if any):"
    request:receiveMessage(function(chunk)
        print("request chunk received:", chunk)
        print "yielded.."
        coroutine.yield(chunk)
    end)
    print("request.message:", request.message)

    print "responding with chunked response:"
    response:addHeader("Date", response.GTM())
    response:addHeader("Content-Type", "text/plain; charset=utf-8")
    response:addHeader("Transfer-Encoding", "chunked")
    
    --TODO!?!?! these need to be one level deep so we can compare to == "chunked"
    -- or when addHeader multiple times the same identifier, then make table out of it
    print(response.header["Transfer-Encoding"], response.header["Transfer-Encoding"] == "chunked")

    local f, line = io.open("uploads/lol.txt", "rb")
    repeat
        line = f:read("*l")
        if line then
            response:sendMessage(line)
            print("response chunk send:", line)
            print "yielded.."
            coroutine.yield(line)
        end
    until not line
    f:close()
    print("response.message:", response.message)
    print("done req/res!")
    return response:submit()
end
