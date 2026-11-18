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
local ipairs = ipairs
local pairs = pairs
local concat = table.concat
local format = string.format
local tostring = tostring
local pcall = pcall
local type = type
local is_int = require('lauxhlib.is').int
local encode_form = require('url').encode_form
local EENCODE = require('error').type.new('form.urlencoded.encode', nil,
                                          'form-urlencoded encode error')

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
--- @field params string[]

--- default_write
--- @param self form.urlencoded.default_writer
--- @param s string
--- @return integer n
local function default_write(self, s)
    self.params[#self.params + 1] = s
    return #s
end

--- encode_flat
--- @param form table
--- @param writer form.urlencoded.writer|form.urlencoded.default_writer
--- @return integer? res
--- @return any err
local function encode_flat(form, writer)
    local stack = {}
    local ctx = {
        tbl = form,
    }
    local nbyte = 0
    local ancestors = {}
    local prev

    while ctx do
        local prefix = ctx.prefix

        if ctx.leave then
            ancestors[ctx.tbl] = nil
        else
            ancestors[ctx.tbl] = true
            -- Leave this table only after all queued children have been processed.
            ctx.leave = true
            stack[#stack + 1] = ctx
            for k, v in pairs(ctx.tbl) do
                local key = to_flatkey(k, prefix)
                if key then
                    local val, has_child = encode_value(v)
                    if val then
                        if prev then
                            local n, err = writer:write(prev .. '&')
                            if err then
                                return nil, err
                            end
                            nbyte = nbyte + n
                        end
                        prev = encode_form(key) .. '=' .. val
                    elseif has_child then
                        if ancestors[v] then
                            return nil, EENCODE:new(
                                       format(
                                           'circular reference found at key %q',
                                           key))
                        end
                        stack[#stack + 1] = {
                            prefix = key,
                            tbl = v,
                        }
                    end
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
        nbyte = nbyte + n
    end

    return nbyte
end

--- encode
--- @param form table
--- @param deeply? boolean
--- @param writer? form.urlencoded.writer
--- @return string|integer|nil res
--- @return any err
local function encode(form, deeply, writer)
    if type(form) ~= 'table' then
        error('form must be table', 2)
    elseif deeply ~= nil and type(deeply) ~= 'boolean' then
        error('deeply must be boolean', 2)
    end

    local params
    if writer == nil then
        params = {}
        writer = {
            write = default_write,
            params = params,
        }
    elseif not pcall(function()
        assert(type(writer.write) == 'function')
    end) then
        error('writer.write must be function', 2)
    end

    if deeply then
        local n, err = encode_flat(form, writer)
        if n and params then
            return concat(params, '')
        end
        return n, err
    end

    local prev
    local nbyte = 0
    for k, v in pairs(form) do
        if type(k) == 'string' then
            local t = type(v)
            if t == 'string' or t == 'number' or t == 'boolean' then
                local val = encode_value(v)
                if val then
                    if prev then
                        local n, err = writer:write(prev .. '&')
                        if err then
                            return nil, err
                        end
                        nbyte = nbyte + n
                    end
                    prev = encode_form(k) .. '=' .. val
                end
            elseif t == 'table' and #v > 0 then
                local key = encode_form(k)
                for _, value in ipairs(v) do
                    local val = encode_value(value)
                    if val then
                        if prev then
                            local n, err = writer:write(prev .. '&')
                            if err then
                                return nil, err
                            end
                            nbyte = nbyte + n
                        end
                        prev = key .. '=' .. val
                    end
                end
            end
        end
    end

    if prev then
        local n, err = writer:write(prev)
        if err then
            return nil, err
        end
        nbyte = nbyte + n
    end

    if params then
        return concat(params, '')
    end
    return nbyte
end

return {
    encode = encode,
}
