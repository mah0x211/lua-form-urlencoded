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
local encode_uri = require('url').encode_uri
local decode_uri = require('url').decode_uri
local new_errno = require('errno').new

--- encode_url
--- @param v string
--- @return string v
local function encode_url(v)
    return encode_uri(gsub(v, ' ', '+'))
end

--- encode_value
--- @param v any
--- @return string|nil v
--- @return boolean|nil is_child
local function encode_value(v)
    local t = type(v)
    if t == 'string' then
        return encode_url(v)
    elseif t == 'number' or t == 'boolean' then
        return encode_url(tostring(v))
    end
    return nil, t == 'table'
end

--- to_flatkey
---@param k any
---@param prefix string|nil
---@return string|nil
local function to_flatkey(k, prefix)
    if is_string(k) then
        if prefix then
            return prefix .. '.' .. k
        end
        return k
    elseif is_int(k) and prefix then
        return prefix
    end
end

--- encode_flat
---@param writer table|userdata
---@param form table
---@return integer|nil nbyte
---@return any error
local function encode_flat(writer, form)
    local stack = {}
    local ctx = {
        tbl = form,
    }
    local nbyte = 0
    local circular = {}
    local prev

    while ctx do
        local prefix = ctx.prefix

        circular[ctx.tbl] = true
        for k, v in pairs(ctx.tbl) do
            local key = to_flatkey(k, prefix)
            if key then
                local val, is_child = encode_value(v)
                if val then
                    if prev then
                        local n, err = writer:write(prev .. '&')
                        if err then
                            return nil, err
                        end
                        nbyte = nbyte + n
                    end
                    prev = encode_url(key) .. '=' .. val
                elseif is_child and not circular[v] then
                    stack[#stack + 1] = {
                        prefix = key,
                        tbl = v,
                    }
                end
            end
        end

        ctx = stack[#stack]
        stack[#stack] = nil
    end

    if prev then
        local n, err = writer:write(prev)
        if err then
            return nil, err
        end
        return nbyte + n
    end

    return 0
end

--- encode
--- @param form table
--- @param deeply boolean
--- @return integer|nil nbyte
--- @return any err
local function encode(writer, form, deeply)
    if not pcall(function()
        assert(is_func(writer.write))
    end) then
        error('writer.write must be function', 2)
    elseif not is_table(form) then
        error('form must be table', 2)
    elseif deeply ~= nil and not is_boolean(deeply) then
        error('deeply must be boolean', 2)
    elseif deeply then
        return encode_flat(writer, form)
    end

    local prev
    local nbyte = 0
    for k, v in pairs(form) do
        if is_string(k) and is_table(v) then
            for _, val in ipairs(v) do
                val = encode_value(val)
                if val then
                    if prev then
                        local n, err = writer:write(prev .. '&')
                        if err then
                            return nil, err
                        end
                        nbyte = nbyte + n
                    end
                    prev = encode_url(k) .. '=' .. val
                end
            end
        end
    end

    if prev then
        local n, err = writer:write(prev)
        if err then
            return nil, err
        end
        return nbyte + n
    end

    return nbyte
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
