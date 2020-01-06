return function(request, response, filename, extension) -- requests to files
    if string.find("jpg jpg png tiff bmp gif svg eps pdf", extension) then -- whitelist look-up
        return response:submit(request.url)
        -- return response:attach(request.url) -- force browser to download file
    end
    return response:submit(nil, nil, 403)
end
