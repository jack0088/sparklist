return function(request, response)
    print "route fired..."
    request:receiveMessage(function(chunk)
        print("chunk received:", chunk)
        coroutine.yield(chunk)
    end)
    -- read another file and chunk respond with its contents here...
    print("request.message:", request.message)
    return response:submit("foobar")
end
