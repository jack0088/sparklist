return function(client)
    -- client.session:set("bljat", "nahui suka bljat pisda")
    return client.response:submit("view/index.lua", "text/html")
end
