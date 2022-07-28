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
local concat = table.concat
local find = string.find
local format = string.format
local gsub = string.gsub
local sub = string.sub
local match = string.match
local tostring = tostring
local pcall = pcall
local type = type
local isa = require('isa')
local is_string = isa.string
local is_boolean = isa.boolean
local is_int = isa.int
local is_uint = isa.uint
local is_table = isa.table
local is_func = isa.func
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

--- key2str
--- @param prefix string
--- @param key any
--- @return string?
local function key2str(prefix, key)
    if is_string(key) then
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
    if not is_table(form) then
        error('form must be table', 2)
    elseif deeply ~= nil and not is_boolean(deeply) then
        error('deeply must be boolean', 2)
    end

    local list
    if deeply then
        list = flatten(form, 0, encode_pair, insert_into_list, key2str)
    else
        list = {}
        for k, v in pairs(form) do
            if is_string(k) then
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

--- decode_value
--- @param v string
--- @return string v
--- @return any err
local function decode_value(v)
    local dec, err = decode_uri(v)
    if err then
        return nil,
               new_errno('EILSEQ', format('illegal character %q found',
                                          sub(v, err, err)), 'urlencoded.decode')
    end

    -- replace '+' to SP
    dec = gsub(dec, '%+', ' ')
    return dec
end

--- decode_kvpair
--- @param form table
--- @param kv string
--- @param deeply boolean
--- @return any err
local function decode_kvpair(form, kv, deeply)
    -- find key/value separator
    local pos = find(kv, '=', 1, true)
    if not pos then
        -- decode key
        local key, err = decode_value(kv)
        if err then
            return err
        end
        push2form(form, key, '', deeply)
    elseif pos > 1 then
        local val = sub(kv, pos + 1)

        -- decode key
        local key, err = decode_value(sub(kv, 1, pos - 1))
        if err then
            return err
        end

        -- decode val
        val, err = decode_value(val)
        if err then
            return err
        end
        push2form(form, key, val, deeply)
    end
end

--- decode
--- @param reader table|userdata
--- @param deeply boolean
--- @return table|nil form
--- @return any err
local function decode(reader, chunksize, deeply)
    -- verify reader
    if not pcall(function()
        assert(is_func(reader.read))
    end) then
        error('reader.read must be function', 2)
    end

    -- verify chunksize
    if chunksize == nil then
        chunksize = 4096
    elseif not is_uint(chunksize) or chunksize < 1 then
        error('chunksize must be uint greater than 0', 2)
    end

    -- verify deeply
    if deeply ~= nil and not is_boolean(deeply) then
        error('deeply must be boolean', 2)
    end

    local form = {}
    local str = ''

    while true do
        -- read chunk
        local s, err = reader:read(chunksize)
        if err then
            return nil, err
        elseif not s or #s == 0 then
            -- use remaining string as key
            str = match(str, '^%s*(.-)%s*$')
            if #str > 0 then
                err = decode_kvpair(form, str, deeply)
                if err then
                    return nil, err
                end
            end
            return form
        end
        str = str .. s

        -- find delimiter
        local head, tail = find(str, '&+')
        while head do
            local kv = match(sub(str, 1, head - 1), '^%s*(.-)%s*$')

            str = sub(str, tail + 1)
            if #kv > 0 then
                err = decode_kvpair(form, kv, deeply)
                if err then
                    return nil, err
                end
            end

            head, tail = find(str, '&+')
        end
    end
end

return {
    encode = encode,
    decode = decode,
}
