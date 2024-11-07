-- boiler!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
local utf8 = require "utf8"

function math.round(n, figs)
    -- synopsis: rounds number
    -- math.round(n [, figs=0])
    -- n: number    - the number to round
    -- figs: number - amount of sigfigs to preserve, e.g math.round(2.357, 2) returns 2.36
    -- returns: number

    figs = figs or 0
    n = n * 10^figs
    return n - math.floor(n) >= 0.5 and math.ceil(n) / 10^figs or math.floor(n) / 10^figs
end

function math.clamp(n, min, max)
    -- synopsis: clamps a number to be inside a range
    -- math.clamp(n, min, max)
    -- n:   number - the number to clamp
    -- min: number - the lower end of the range
    -- max: number - the higher end of the range
    -- returns: number

    return math.min(math.max(n, min), max)
end

function math.inside(n, from, to, set)
    -- synopsis: checks if a number is inside a range
    -- math.inside(n, from, to [, set="[]"])
    -- n:    number - the number to check
    -- from: number - the lower end of the range
    -- to:   number - the higher end of the range
    -- set:  string - the type of set to use
        -- set = "[]" - from and to are included in the range
        -- set = "(]" - only to is included in the range; if n == from then it's not in the range
        -- set = "[)" - only from is included in the range; if n == to then it's not in the range
        -- set = "()" - neither from or to are in the range; if n == from or n == to then it's not in the range
    -- returns: boolean

    set = set or "[]"
    return n == math.clamp(n, from, to) and ((n ~= from and set:sub(1, 1) == "(") or set:sub(1, 1) == "[") and ((n ~= to and set:sub(2, 2) == ")") or set:sub(2, 2) == "]")
end

-- all the string functions can be called directly onto a string like the rest
-- so you can do ("  blah  "):trim() like you could with ("ahhhgh"):len()

function string.setsplit(str, pattern, strict)
    -- use string.split instead, kept this in just incase

    -- synopsis: splits a string with a set of characters
    -- string.setsplit(str, pattern [, strict="+"])
    -- str:     string - the string to split
    -- pattern: string - the characters in the set
    -- strict:  string - the pattern item to use, can be of "+-*?"
    -- returns: table

    local got = {}
    local strict = strict or "+"

    for m in string.gmatch(str, "([^"..pattern.."]"..strict..")") do
        got[#got+1] = m
    end

    return got
end

function string.split(str, pattern, delim)
    -- synopsis: splits a string at every occurence of a substring
    -- string.split(str, pattern [, delim="\3"])
    -- str:     string - the string to split
    -- pattern: string - the substring to split at, can also be a pattern
    -- delim:   string - the delimiter to use, only change if your string uses \3 for whatever reason
    -- returns: table

    local got   = {}
    local delim = delim or "\3"
    str = str:gsub(pattern, delim)..delim

    for m in string.gmatch(str, "(.-)"..delim) do
        got[#got+1] = m
    end

    return got
end

function fromHSV(h, s, v, a)
    -- synopsis: converts HSV values to RGB
    -- fromHSV(h, s, v [, a=1])
    -- h: number - hue
    -- s: number - saturation
    -- v: number - value/lightness/luminance
    -- a: number - opacity (0-1)

    h = h / 360
    s = s / 100
    v = v / 100

    local r, g, b;

    if s == 0 then
        r, g, b = v, v, v; -- achromatic
    else
        local function hue2rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1 / 6 then return p + (q - p) * 6 * t end
            if t < 1 / 2 then return q end
            if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
            return p;
        end

        local q = v < 0.5 and v * (1 + s) or v + s - v * s;
        local p = 2 * v - q;
        r = hue2rgb(p, q, h + 1 / 3);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1 / 3);
    end

    return r, g, b, a or 1
end

function fromRGB(r, g, b, a)
    -- synopsis: turns a color with values up to 255 to a usable color for love.graphics.setColor()
    -- fromRGB(r, g, b [, a=255])
    -- r: number - the red component
    -- g: number - the green component
    -- b: number - the blue component
    -- a: number - the alpha component
    -- returns: number, number, number, number

    return r / 255, g / 255, b / 255, (a or 255) / 255
end

function fromHEX(h)
    -- synopsis: converts a hex color to a usable color for love.graphics.setColor()
    -- fromHEX(h)
    -- h: string - the hex color, all forms are supported (#rgb, #rgba, #rrggbb, #rrggbbaa)
    -- returns: number, number, number, number
    -- Note: returns nil if hex color is invalid
    -- Note: hashtag is optional

    h = h:sub(1, 1) == "#" and h:sub(2, -1) or h
    h = h:lower()
    if #h ~= 3 and #h ~= 4 and #h ~= 6 and #h ~= 8 then return end
    if h:find("[^abcdef1234567890]")               then return end
    local vals = {}

    for i=1, #h, #h < 6 and 1 or 2 do
        vals[#vals+1] = tonumber(string.rep(string.sub(h, i, #h < 6 and i or i + 1), #h < 6 and 2 or 1), 16)
    end

    return vals[1] / 255, vals[2] / 255, vals[3] / 255, (vals[4] or 255) / 255
end

function string.validUTF8(text, replace)
    -- synpsis: turns a string into valid UTF8 if it's invalid
    -- string.validUTF8(text [, replace="�"])
    -- text:    string - the text to validate
    -- replace: string - what to replace invalid characters with
    -- returns: string

    text = tostring(text)
    replace = replace or "�"
    local success, pos = utf8.len(text)

    if not success then
        text = text:sub(0, pos-1)..replace..text:sub(pos+1, -1)
        return validUTF8(text)
    end

    return text
end

function string.trim(text)
    -- synopsis: trims a string of trailing or preceding whitespace (" " and "\n")
    -- text: string - the text to trim
    -- returns: string

    return text:gsub("^%s*(.-)%s*$", "%1")
end

function typeof(thing)
    -- only really useful if you use the other modules ngl
    return type(getmetatable(thing)) == "string" and getmetatable(thing) or type(thing)
end

function dump(table, nest, delim, newline) -- ugly looking code tbh
    -- synopsis: creates a readable string out of a table
    -- dump(table [, nest=0 [, delim="\t" [, newline="\n"]]])
    -- table:   table  - the table to dump
    -- nest:    number - how far deep is it nested? used by delim
    -- delim:   string - the delimiter to use, repeated based on nest value
    -- newline: string - the separator between values
    -- returns: string
    -- Note: if table isn't a table, it'll do tostring() instead

    if string.find("table", typeof(table)) then -- you can change "table" here to also include other values, like "table,vector2"
        local s = ""
        nest = nest or 0
        delim = delim or "\t"
        newline = newline or "\n"

        for i,v in pairs(table) do
            if typeof(i) == "string" and i:match("^[%a_][%d%a_]*$") then s = s..delim:rep(nest)..i.." = "
                                                                    else s = s..delim:rep(nest).."["..(type(i) == "string" and "\"" or "")..tostring(i)..(type(i) == "string" and "\"" or "").."] = " end

            if typeof(v) == "table" then
                local has = false for _ in pairs(v) do has = true break end

                if has then
                    s = s.."{"..newline..dump(v, nest + 1, delim, newline)..newline..delim:rep(nest).."},"
                else
                    s = s.."{},"
                end
            elseif typeof(v) == "string" then
                s = s.."\""..v.."\","
            else
                s = s..tostring(v)..","
            end

            s = s..newline
        end

        return s:sub(1, -3)
    else
        return tostring(table)
    end
end