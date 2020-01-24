-- 2019 (c) kontakt@herrsch.de

-- client response generator
-- a response runs after every request from client to server


local runstring = loadstring or load -- Lua > 5.1
local hotload = require "hotload"
local class = hotload "class"
local dt = hotload "datetime"
local utilities = hotload "utilities"
local Header = hotload "header"
local Message = hotload "message"
local Response = class()


Response.file = function(url)
    local handle = io.open(url, "rb")
    if handle then
        local content = handle:read("*a")
        handle:close()
        -- return (binary) content, mime-type, status-code
        return content, utilities.filemime(url), 200
    end
    return nil, nil, 400
end


function Response:new(receiver, request)
    self.receiver = receiver -- client socket object
    self.request = request
    self.header = Header()
    self.message = Message()
end


function Response:sendHeader(status)
    return self.header:send(self.receiver, status)
end


function Response:sendMessage(stream)
    local chunked = tostring(self.header:get("Transfer-Encoding")):match("chunked") == "chunked"
    return self.message:send(self.receiver, stream, chunked)
end


function Response:submit(content, mime, status, ...)
    if (self.header.sent or self.message.sent) and content == nil and mime == nil and status == nil then
        return self:sendMessage() -- finish up ongoing response
    end
    assert(not self.header.sent, "incomplete header sent too early")
    if type(content) == "string" and #content > 0 then
        local file_extension = content:match("%.%w%w[%w%p]*$")
        if file_extension then
            local file_content, file_mime, response_status = self.file(content:gsub("^[%./]+", ""))
            if file_extension == ".lua" and type(file_content) == "string" and (mime or ""):match("^text/html.*") ~= nil then
                -- response with *.lua file and explicit @mime of "text/html" means we want a view template
                local view_loader = assert(runstring(file_content))()
                local html_content = assert(view_loader(...))
                content = html_content
            else
                -- resond with file contents
                -- NOTE @mime must match its actual file encoding, e.g. *.txt file saved in charset=utf-8 must be passed with "text/plain; charset=utf-8"
                content = file_content
                mime = mime or file_mime
                status = status or response_status
            end
        end
    end
    if not content then
        status = status or 400
        mime = mime or "text/html"
        content = assert(dofile("view/error.lua"))(
            self.request.header.path,
            self.request.header.method,
            status,
            self.header.HTTP_STATUS_MESSAGE[status]
        )
    end
    self.header:set("Date", dt.date()) -- update/assign
    self.header:set("Content-Type", mime or "text/plain")
    self.header:set("Content-Length", #content)
    self:sendHeader(status or 200)
    return self:sendMessage(content)
end


function Response:refresh(url, timeout, content, mime, ...)
    self.header:set("Refresh", tostring(timeout or 0).."; URL="..(url or self.request.path))
    if content then -- just set the header if content is missing
        return self:submit(content, mime, nil, ...)
    end
end


function Response:redirect(url)
    self.header:set("Location", url) -- with browser back-button support
    return self:submit(nil, nil, 307) -- instant, automatic request forward with unchanged request method and body
end


function Response:attach(location, name) -- attach file and force client/browser to download it from given location [with custom name]
    local filename, extension = location:match("(.+)(%.%w%w[%w%p]*)$")
    self.header:set("Content-Disposition", string.format("attachment; filename=%s", name or filename))
    return self:submit(location)
end


return Response
