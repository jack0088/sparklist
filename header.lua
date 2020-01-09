local class = require "class"
local Header = class()


-- local __HEADER = class()


-- __HEADER["get_(%w+)"] = function(self, name)
--     if type(self[name]) == "table" then -- multiple values for same header-field
--         local concatenation = ""
--         for _, v in ipairs(name) do
--             concatenation = concatenation..v
--         end
--         return concatenation
--     end
--     return self[name] -- single key-value pair header
-- end


-- __HEADER["set_(%w+)"] = function(self, value, name)
--     if type(self[name]) == "table" then
--         table.insert(self[name], value)
--     elseif type(self.name) == "string" then
--         self[name] = {{self[name]}, {value}}
--     else
--         self[name] = value
--     end
-- end


Header.QUERY = "([%w%p]+): ([%w%p ]+)"

Header.URL = "([^=]*)=([^&]*)&?"
Header.PARAM = "^([^#?]+)[#|?]?(.*)"
Header.COOKIE = "([^=]*)=([^;]*);?%s?"


function Header:new(query)
    local class_methods = {}
    for prop, _ in pairs(self) do table.insert(class_methods, prop) end
    class_methods = "|"..table.concat(class_methods, "|").."|"

    self["get_(%w+)"] = function(this, name)
        if class_methods:match(name) ~= name then
            if type(rawget(this, name)) == "table" then -- multiple values for same header-field
                local concat = ""
                for _, v in ipairs(name) do concat = concat..", "..v end
                return concat
            end
        end
        return rawget(this, name)
    end
    
    self["set_(%w+)"] = function(this, value, name)
        if class_methods:match(name) ~= name then
            if type(rawget(this, name)) == "table" then
                table.insert(rawget(this, name), value)
            elseif type(self.name) == "string" then
                rawset(rawget(this, name), {{this[name]}, {value}})
            end
        end
        rawset(this, name, value)
    end

    if type(query) == "string" then
        for header_name, header_value in query:gmatch(self.QUERY) do
            if header_name and header_value then
                if not self[header_name] then
                    self[header_name] = header_value
                else
                    -- NOTE duplicated header-fields may occur in requests or resposes and can be concatenated into a comma separated query resulting in a single combined header, as stated here https://stackoverflow.com/questions/39912920/how-to-interpret-multiple-accept-headers and here https://stackoverflow.com/questions/3096888/standard-for-adding-multiple-values-of-a-single-http-header-to-a-request-or-resp
                    self[header_name] = self[header_name]..", "..header_value
                end
            end
        end
    end
end


function Header:parse(header, pattern_recipe)
    -- TODO
    --take header and split it into parts like cookies into a list of single cookie or multiple header-fields into list of single (duplicate) headers
    -- resulting header-values can be :split() further into attributes if any
end


function Header:split(header, pattern_recipe)
    -- TODO split a header_value into its single attributes like cookie into value, expires, domain, etc.
end


function Header:serialize(header, pattern_recipe)
    -- NOTE just a reminder: servers are allowed to respond with same header-field multiple times like Set-Cookie but clients MUST send only one concaneted header for Cookie
    local query = ""
    for header_name, header_value in pairs(self) do
        if header_name:match("^(_+).+") == nil then -- ignore "private" keys that start with underscore like __parent!
            query = query..string.format("%s: %s\r\n", header_name, header_value)
        end
    end
    return query
end


function Header:add(header_name, header_value)
    if header_name == "Set-Cookie" then -- we optionally append some security settings to cookies
        local function unpack_attributes(cookie)
            local attributes = {}
            for k, v in string.gmatch(cookie, "([^=; ]+)=([^=;]+)") do
                k = k:lower():gsub("%p", "")
                if not string.find("expires maxage domain path secure httponly samesite", k) then
                    attributes.name, attributes.value = k, v
                else
                    attributes[k] = v
                end
            end
            return attributes
        end

        local function verify_attributes(cookie)
            -- add security recomendations for cookies, see https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie and https://tools.ietf.org/html/rfc6265#page-7
            assert(cookie.name, cookie.value, "cookie header is missing attributes")
            cookie.name = cookie.name:gsub("%p*", "") -- trim punctuation
            cookie.httponly = cookie.httponly == false and false or true -- nil defaults to true
            cookie.samesite = cookie.samesite or "Lax"
            return cookie
        end

        local function pack_attributes(cookie)
            local query = string.format("%s=%s", cookie.name, cookie.value)
            if cookie.expires then query = query.."; Expires="..cookie.expires end
            if cookie.maxage then query = query.."; Max-Age="..cookie.maxage end
            if cookie.domain then query = query.."; Domain="..cookie.domain end
            if cookie.path then query = query.."; Path="..cookie.path end
            if cookie.secure then query = query.."; Secure" end
            if cookie.httponly then query = query.."; HttpOnly" end
            if cookie.samesite then query = query.."; SameSite="..cookie.samesite end
            return query
        end

        header_value = pack_attributes(verify_attributes(unpack_attributes(header_value)))
    end
    
    if not self[header_name] then
        self[header_name] = header_value
    else
        self[header_name] = self[header_name]..", "..header_value
    end
end


local test = Header("Host: localhost\r\nPragma: no-cache\r\nConnection: keep-alive\r\nUpgrade-Insecure-Requests: 1\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.4 Safari/605.1.15\r\nAccept-Language: de-de\r\nCache-Control: no-cache\r\nAccept-Encoding: gzip, deflate")
-- print(test.foobar)
test.foobar = "foobar"
-- print(test.foobar)
-- print()
for k, v in pairs(test) do print(k) end


return Header
