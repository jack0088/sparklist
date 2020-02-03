return function(client)
    -- ignore request and respond with error 400
    return client.response:submit()
end