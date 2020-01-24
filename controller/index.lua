return function(request, response)
    -- request.header.session:set("bljat", "nahui suka bljat pisda")
    return response:submit("view/index.lua", "text/html")
end
