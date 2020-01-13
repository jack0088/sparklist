return function(request, response, filename, extension) -- requests to files
    local allowed_extensions = {
        "jpg",
        "jpeg",
        "png",
        "tiff",
        "bmp",
        "gif",
        "svg",
        "eps",
        "pdf",
        "txt"
    }
    if table.concat(allowed_extensions, " "):find(extension) then -- whitelist look-up
        return response:submit(request.url)
        -- return response:attach(request.url) -- force browser to download file
    end
    return response:submit(nil, nil, 403)
end
