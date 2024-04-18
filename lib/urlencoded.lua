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
local ipairs = ipairs
local pairs = pairs
local concat = table.concat
local find = string.find
local format = string.format
local sub = string.sub
local match = string.match
local tostring = tostring
local pcall = pcall
local type = type
local is = require('lauxhlib.is')
local is_int = is.int
local is_uint = is.uint
local encode_form = require('url').encode_form
local decode_form = require('url').decode_form
-- constants
local EDECODE = require('error').type.new('form.urlencoded.decode', nil,
                                          'form-urlencoded decode error')

--- encode_value
--- @param v any
--- @return string? v
--- @return boolean? is_child
local function encode_value(v)
    local t = type(v)
    if t == 'string' then
        return encode_form(v)
    elseif t == 'number' or t == 'boolean' then
        return encode_form(tostring(v))
    end
    return nil, t == 'table'
end

--- to_flatkey
--- @param k any
--- @param prefix? string
--- @return string? key
local function to_flatkey(k, prefix)
    if type(k) == 'string' then
        if prefix then
            return prefix .. '.' .. k
        end
        return k
    elseif is_int(k) and prefix then
        return prefix
    end
end

--- @class form.urlencoded.writer
--- @field write fun(self, s:string):(n:integer?,err:any)

--- @class form.urlencoded.default_writer : form.urlencoded.writer
--- @field params? string[]
local DefaultWriter = {
    write = function(self, s)
        self.params[#self.params + 1] = s
        return #s, nil
    end,
}

--- reset_default_writer
--- @param writer form.urlencoded.writer
--- @return string[]? params
local function reset_default_writer(writer)
    if writer == DefaultWriter and DefaultWriter.params then
        local params = DefaultWriter.params
        DefaultWriter.params = nil
        return params
    end
end

--- encode_flat
--- @param form table
--- @param writer form.urlencoded.writer|form.urlencoded.default_writer
--- @return integer|string? res
--- @return any err
local function encode_flat(form, writer)
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
                local val, has_child = encode_value(v)
                if val then
                    if writer and prev then
                        local n, err = writer:write(prev .. '&')
                        if err then
                            reset_default_writer(writer)
                            return nil, err
                        end
                        nbyte = nbyte + n
                    end
                    prev = encode_form(key) .. '=' .. val
                elseif has_child and not circular[v] then
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
            reset_default_writer(writer)
            return nil, err
        end
        nbyte = nbyte + n
    end

    local params = reset_default_writer(writer)
    if params then
        return concat(params, '')
    end

    return nbyte
end

--- encode
--- @param form table
--- @param deeply boolean
--- @param writer form.urlencoded.writer
--- @return integer|string? res
--- @return any err
local function encode(form, deeply, writer)
    if type(form) ~= 'table' then
        error('form must be table', 2)
    elseif deeply ~= nil and type(deeply) ~= 'boolean' then
        error('deeply must be boolean', 2)
    end

    if writer == nil then
        writer = DefaultWriter
        writer.params = {}
    elseif not pcall(function()
        assert(type(writer.write) == 'function')
    end) then
        error('writer.write must be function', 2)
    end

    if deeply then
        return encode_flat(form, writer)
    end

    local prev
    local nbyte = 0
    for k, v in pairs(form) do
        if type(k) == 'string' then
            local t = type(v)
            if t == 'string' then
                local val = encode_value(v)
                if val then
                    if prev then
                        local n, err = writer:write(prev .. '&')
                        if err then
                            reset_default_writer(writer)
                            return nil, err
                        end
                        nbyte = nbyte + n
                    end
                    prev = encode_form(k) .. '=' .. val
                end
            elseif t == 'table' and #v > 0 then
                k = encode_form(k)
                for _, val in ipairs(v) do
                    val = encode_value(val)
                    if val then
                        if prev then
                            local n, err = writer:write(prev .. '&')
                            if err then
                                reset_default_writer(writer)
                                return nil, err
                            end
                            nbyte = nbyte + n
                        end
                        prev = k .. '=' .. val
                    end
                end
            end
        end
    end

    if prev then
        local n, err = writer:write(prev)
        if err then
            reset_default_writer(writer)
            return nil, err
        end
        nbyte = nbyte + n
    end

    local params = reset_default_writer(writer)
    if params then
        return concat(params, '')
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
    local dec, err = decode_form(v)
    if err then
        return nil, EDECODE:new(
                   format('illegal character %q found', sub(v, err, err)))
    end
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

--- @class form.urlencoded.reader
--- @field read fun(self, n:integer):(s:string?,err:any)

--- decode
--- @param chunk string|form.urlencoded.reader
--- @param deeply boolean
--- @param chunksize? integer
--- @return table? form
--- @return any err
local function decode(chunk, deeply, chunksize)
    local str = ''
    local no_read = true

    -- verify chunk
    if type(chunk) == 'string' then
        str = chunk
        no_read = false
    elseif not pcall(function()
        assert(type(chunk.read) == 'function')
    end) then
        error('chunk must be string or it must have read method', 2)
    elseif chunksize == nil then
        chunksize = 4096
    elseif not is_uint(chunksize) or chunksize < 1 then
        error('chunksize must be uint greater than 0', 2)
    end

    -- verify deeply
    if deeply ~= nil and type(deeply) ~= 'boolean' then
        error('deeply must be boolean', 2)
    end

    local form = {}
    while true do
        -- find delimiter
        local head, tail = find(str, '&+')
        while head do
            local kv = match(sub(str, 1, head - 1), '^%s*(.-)%s*$')

            str = sub(str, tail + 1)
            if #kv > 0 then
                local err = decode_kvpair(form, kv, deeply)
                if err then
                    return nil, err
                end
            end
            head, tail = find(str, '&+')
        end

        if not no_read then
            break
        end

        -- read chunk
        local s, err = chunk:read(chunksize)
        if err then
            return nil, err
        elseif not s or #s == 0 then
            break
        end
        str = str .. s
    end

    -- use remaining string as key
    str = match(str, '^%s*(.-)%s*$')
    if #str > 0 then
        local err = decode_kvpair(form, str, deeply)
        if err then
            return nil, err
        end
    end
    return form
end

return {
    encode = encode,
    decode = decode,
}
