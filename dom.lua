-- 2019 (c) kontakt@herrsch.de
--[[

NAIVE HTML DSL ([kind of] Domain Specific Language)
for describing and generating HTML layouts via Lua
Its purpose is to allow mixing Lua and HTML code in the same context.

The `dom` object lets you create single html elements
optionally in hierarchical nested order
or groups/countainers these html elements.


EXAMPLE (single html element)

    dom.meta{charset = "utf-8"}


EXAMPLE (hierarchical nesting of html elements)

    dom.head{
        dom.title "404",
        dom.meta{charset = "utf-8"}
    }


EXAMPLE (top level group, single and nested html elements)

    local dom = require "dom"

    local echo = {}
    for i = 1, 10 do
        table.insert(echo, dom.p "sorry, i could not find this page")
    end

    local view = dom{ -- especially useful when sourcing because no enclosing html tag is generated for this group
        dom["!doctype"] "html",
        dom.html{
            dom.head{
                dom.title "404",
                dom.meta{charset = "utf-8"}
            },
            dom.body{
                dom.h1 "not found",
                echo
            }
        }
    }

    return view.htmlsource


EXAMPLE (access elements and element attributes)

    print(view.html.head.meta.attributes.charset)


EXAMPLE (append a html element after the fact)

    local url = "/"
    local key = view.html.body.innerHTML
    key[#key + 1] = dom.p(string.format('requested url: %s', url))

--]]


local SELF_CLOSING_TAGS = { -- sorted alphabetically
    "area",
    "base",
    "br",
    "col",
    "command",
    "embed",
    "hr",
    "img",
    "input",
    "keygen",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
    "!doctype"
}


local SPECIAL_CHARACTERS = {
    ["{"] = "&#123;",
    ["}"] = "&#125;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ["&"] = "&amp;",
    ["/"] = "&#47;",
    ['"'] = "&quot;",
    ["'"] = "&#39;"
}


local function solo(element) -- determine if element needs a closing tag
    for _, elem in ipairs(SELF_CLOSING_TAGS) do
        if elem == element then return true end
    end
    return false
end


local function trim(str) -- removes whitespaces, tabs and new lines from beginning and ending of a string
    if type(str) ~= "string" then return str end
    local mask = "[ \t\r\n]*"
    return str:gsub("^"..mask, ""):gsub(mask.."$", "")
end


local function escape(str)
    if type(str) ~= "string" then return str end
    local blacklist = ""
    for char in pairs(SPECIAL_CHARACTERS) do blacklist = blacklist.."%"..char end
    return trim(str):gsub("["..blacklist.."]", SPECIAL_CHARACTERS)
end


local function source(node) -- generate and serialize a html tag from a descriptor node
    if not node then return end
    if type(node) == "string" then return node end
    if #node > 0 then
        local src = ''
        for _, n in ipairs(node) do
            src = src..source(n)
        end
        return src
    end
    if not node.tagName and node.innerHTML then -- container/group
        return source(node.innerHTML)
    end
    local standalone, attributes = solo(node.tagName), ''
    if type(node.attributes) == "table" then
        for k, v in pairs(node.attributes) do
            attributes = attributes..string.format(v ~= '' and ' %s="%s"' or ' %s', k, v)
        end
    end
    return string.format(
        '%s%s%s',
        string.format( -- opening tag?
            '<%s%s%s>',
            node.tagName,
            attributes,
            (standalone and node.innerHTML) and ' '..source(node.innerHTML) or ''
        ),
        not standalone and source(node.innerHTML) or '', -- content inside element open/close tags?
        not standalone and string.format('</%s>', node.tagName) or '' -- closing tag?
    )
end


local function generate(node, property)
    if property ~= "tagName" and property ~= "attributes" and property ~= "innerHTML" then
        if type(node.innerHTML) == "table" then
            for k, v in ipairs(node.innerHTML) do
                if v.tagName == property then
                    return v -- show tree
                end
            end
        end
        return source(node)
    end
end


local function tree(element, attributes) -- build tag descriptor node with dependency hierarchie
    local node = setmetatable({}, {__index = generate})
    if type(element) == "string" and element ~= "" then
        node.tagName = element
    end
    if type(attributes) ~= "table" then
        node.innerHTML = attributes
        return node
    end
    for key, value in pairs(attributes) do
        if type(key) == "number" or key == "innerHTML" then
            if type(value) == "table" then
                if not node.innerHTML then node.innerHTML = {} end
                if type(node.innerHTML) == "string" then node.innerHTML = node.innerHTML..source(value)
                else node.innerHTML[key] = value end
            else
                if not node.innerHTML then node.innerHTML = "" end
                if type(node.innerHTML) == "string" then node.innerHTML = node.innerHTML..value
                else node.innerHTML = source(node.innerHTML)..value end
            end
        else
            if not node.attributes then node.attributes = {} end
            node.attributes[key] = tostring(value)
        end
    end
    return node
end


local function process(element_name, element_attributes)
    return tree(element_name, element_attributes)
end


local function access(_, element)
    return function(...)
        return process(element, ...)
    end
end


-- extend built-in string module to support trimmin and escaping of unsecure strings
local string_meta = getmetatable("")
string_meta.__index.trim = trim
string_meta.__index.escape = escape


return setmetatable({}, {__index = access, __call = process}) -- dom
