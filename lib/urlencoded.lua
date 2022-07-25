--
-- Copyright (C) 2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--- assign to local
local floor = math.floor
local concat = table.concat
local find = string.find
local format = string.format
local gsub = string.gsub
local sub = string.sub
local tostring = tostring
local type = type
local flatten = require('table.flatten')
local encode_uri = require('url').encode_uri
local decode_uri = require('url').decode_uri
local new_errno = require('errno').new

--- insert_into_list
--- @param list string[]
--- @param key string
--- @param val string
local function insert_into_list(list, key, val)
    if key then
        key = gsub(key, ' ', '+')
        val = gsub(val, ' ', '+')
        list[#list + 1] = encode_uri(key) .. '=' .. encode_uri(val)
    end
end

--- encode_pair
--- @param key string
--- @param val any
--- @return string key
--- @return string val
local function encode_pair(key, val)
    -- ignore parameters that begin with a numeric index
    if find(key, '^[a-zA-Z_]') then
        -- ignore parameters that begin with a numeric index
        local t = type(val)
        if t == 'string' then
            return key, val
        elseif t == 'number' or t == 'boolean' then
            return key, tostring(val)
        end
    end
    -- ignore arguments except string|number|boolean
end

--- constants
local INF_POS = math.huge
local INF_NEG = -INF_POS

local function is_int(v)
    return type(v) == 'number' and (v < INF_POS and v > INF_NEG) and floor(v) ==
               v
end

--- key2str
--- @param prefix string
--- @param key any
--- @return string?
local function key2str(prefix, key)
    if type(key) == 'string' then
        if prefix then
            return prefix .. '.' .. key
        end
        return key
    elseif is_int(key) then
        return prefix
    end
end

--- encode
--- @param form table
--- @param deeply boolean
--- @return string str
local function encode(form, deeply)
    if type(form) ~= 'table' then
        error('form must be table', 2)
    elseif deeply ~= nil and type(deeply) ~= 'boolean' then
        error('deeply must be boolean', 2)
    end

    local list
    if deeply then
        list = flatten(form, 0, encode_pair, insert_into_list, key2str)
    else
        list = {}
        for k, v in pairs(form) do
            if type(k) == 'string' then
                k, v = encode_pair(k, v)
                if k then
                    insert_into_list(list, k, v)
                end
            end
        end
    end

    -- set new query-string
    if #list > 0 then
        return concat(list, '&')
    end
    return ''
end

--- decode_value
--- @param v string
--- @param vhead integer
--- @return string v
--- @return any err
local function decode_value(v, vhead)
    local dec, err = decode_uri(v)
    if err then
        return nil,
               new_errno('EILSEQ', format('illegal character %q found at %d',
                                          sub(v, err, err), vhead + err),
                         'urlencoded.decode')
    end

    -- replace '+' to SP
    dec = gsub(dec, '%+', ' ')
    return dec
end

--- push2form
--- @param form table
--- @param key string
--- @param val string
--- @param deeply boolean
--- @return table form
local function push2form(form, key, val, deeply)
    local list = form

    if deeply then
        local pos = 1
        local tail = find(key, '.', pos, true)
        while tail do
            local k = sub(key, pos, tail - 1)
            local child = list[k]
            if not child then
                child = {}
                list[k] = child
            end
            list = child

            pos = tail + 1
            tail = find(key, '.', pos, true)
        end

        if pos < #key then
            local k = sub(key, pos)
            local child = list[k]
            if not child then
                child = {}
                list[k] = child
            end
            list = child
        end
    else
        local child = list[key]
        if not child then
            child = {}
            list[key] = child
        end
        list = child
    end

    list[#list + 1] = val
    return form
end

--- decode
--- @param str string
--- @param deeply boolean
--- @return table form
--- @return any err
local function decode(str, deeply)
    if type(str) ~= 'string' then
        error('str must be string', 2)
    elseif deeply ~= nil and type(deeply) ~= 'boolean' then
        error('deeply must be boolean', 2)
    end

    local form = {}
    local tail = #str
    local key, val, err

    -- find key: '...='
    local khead = 1
    local ktail = find(str, '=', khead, true)
    while ktail do
        if khead == ktail then
            -- key not found
            -- skip value: '=...&'
            khead = find(str, '&', ktail, true)
            if not khead then
                -- end-of-data
                return form
            end
            khead = khead + 1
        else
            -- decode key
            key, err = decode_value(sub(str, khead, ktail - 1), khead)
            if err then
                return nil, err
            end

            -- find val: '...&'
            local vhead = ktail + 1
            local vtail = find(str, '&', vhead, true)
            if not vtail then
                -- end-of-data
                -- decode val
                val, err = decode_value(sub(str, vhead), vhead)
                if err then
                    return nil, err
                end

                return push2form(form, key, val, deeply)

            elseif vhead == vtail then
                -- val not found
                push2form(form, key, '', deeply)
            else
                -- decode val
                val, err = decode_value(sub(str, vhead, vtail - 1), vhead)
                if err then
                    return nil, err
                end
                push2form(form, key, val, deeply)
            end

            khead = vtail + 1
        end

        -- find key: '...='
        ktail = find(str, '=', khead, true)
    end

    if khead < tail then
        key, err = decode_value(sub(str, khead), khead)
        if err then
            return nil, err
        end
        return push2form(form, key, '', deeply)
    end

    return form
end

return {
    encode = encode,
    decode = decode,
}
