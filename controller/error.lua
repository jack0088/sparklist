return function(request, response)
    -- ignore request and respond with 404 error
    return response:submit()
end