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
local sort = table.sort
local format = string.format
local tostring = tostring
local pcall = pcall
local type = type
local is_int = require('lauxhlib.is').int
local encode_form = require('url').encode_form
local EENCODE = require('error').type.new('form.urlencoded.encode', nil,
                                          'form-urlencoded encode error')

--- Encode a scalar form value or identify a child table for traversal.
--- @param v any
--- @return string? encoded Percent-encoded scalar, or nil for other types.
--- @return boolean? is_child True for a table, false for an unsupported type.
local function encode_value(v)
    local t = type(v)
    if t == 'string' then
        return encode_form(v)
    elseif t == 'number' or t == 'boolean' then
        return encode_form(tostring(v))
    end
    return nil, t == 'table'
end

--- Compare pending values by their integer keys for ascending order.
--- @param a form.urlencoded.indexed_value
--- @param b form.urlencoded.indexed_value
--- @return boolean before Whether a should precede b.
local function by_index(a, b)
    return a.index < b.index
end

--- @class form.urlencoded.writer
--- @field write fun(self, s:string):(n:integer?,err:any)

--- @class form.urlencoded.default_writer : form.urlencoded.writer
--- @field params string[]

--- Append an encoded chunk to the default writer's output buffer.
--- @param self form.urlencoded.default_writer
--- @param s string Encoded chunk.
--- @return integer n Number of bytes appended.
local function default_write(self, s)
    self.params[#self.params + 1] = s
    return #s
end

--- @class form.urlencoded.table_visit
--- @field tbl table Table to visit or leave.
--- @field prefix? string Flattened key of the table, absent for the root.
--- @field leave? boolean Whether to remove the table from the active path.

--- @class form.urlencoded.indexed_value
--- @field index integer Original key within the parent table.
--- @field prefix string Flattened key shared by the parent's integer-keyed values.
--- @field value any Value to encode or traverse.

--- @class form.urlencoded.encode_state
--- @field writer form.urlencoded.writer
--- @field stack (form.urlencoded.table_visit|form.urlencoded.indexed_value)[] Pending traversal work.
--- @field ancestors table<table, boolean> Tables on the active traversal path.
--- @field nbyte integer Total bytes reported by the writer.
--- @field prev? string Encoded pair held until its trailing separator is known.

--- Queue a child table or buffer a scalar pair, flushing the previous pair if needed.
--- @param state form.urlencoded.encode_state
--- @param key string Flattened key before percent-encoding.
--- @param value any
--- @return true? ok True when the value was handled or skipped, nil on failure.
--- @return any err Writer error or circular-reference error.
local function visit_value(state, key, value)
    local val, has_child = encode_value(value)
    if val then
        if state.prev then
            local n, err = state.writer:write(state.prev .. '&')
            if err then
                return nil, err
            end
            state.nbyte = state.nbyte + n
        end
        state.prev = encode_form(key) .. '=' .. val
    elseif has_child then
        if state.ancestors[value] then
            return nil, EENCODE:new(
                       format('circular reference found at key %q', key))
        end
        state.stack[#state.stack + 1] = {
            prefix = key,
            tbl = value,
        }
    end
    return true
end

--- Flatten nested form keys and write their pairs in URL-encoded form.
--- @param form table Form fields to encode.
--- @param writer form.urlencoded.writer
--- @return integer? n Number of bytes reported by the writer, or nil on failure.
--- @return any err Writer error or circular-reference error.
local function encode_flat(form, writer)
    local state = {
        writer = writer,
        stack = {},
        ancestors = {},
        nbyte = 0,
    }
    local stack = state.stack
    local ctx = {
        tbl = form,
    }

    while ctx do
        local prefix = ctx.prefix

        if ctx.leave then
            state.ancestors[ctx.tbl] = nil
        elseif ctx.index then
            local ok, err = visit_value(state, prefix, ctx.value)
            if not ok then
                return nil, err
            end
        else
            state.ancestors[ctx.tbl] = true
            -- Leave this table only after all queued children have been processed.
            ctx.leave = true
            stack[#stack + 1] = ctx

            local indexed
            for k, v in pairs(ctx.tbl) do
                if type(k) == 'string' then
                    local key = prefix and prefix .. '.' .. k or k
                    local ok, err = visit_value(state, key, v)
                    if not ok then
                        return nil, err
                    end
                elseif prefix and is_int(k) then
                    indexed = indexed or {}
                    indexed[#indexed + 1] = {
                        index = k,
                        prefix = prefix,
                        value = v,
                    }
                end
            end
            if indexed then
                sort(indexed, by_index)
                -- Reverse the push order so each indexed value and its
                -- descendants are visited before the next indexed value.
                for i = #indexed, 1, -1 do
                    stack[#stack + 1] = indexed[i]
                end
            end
        end

        ctx = stack[#stack]
        stack[#stack] = nil
    end

    if state.prev then
        local n, err = writer:write(state.prev)
        if err then
            return nil, err
        end
        state.nbyte = state.nbyte + n
    end

    return state.nbyte
end

--- Require the writer's write member to be a function.
--- @param writer any Candidate writer to validate with pcall.
local function check_writer(writer)
    assert(type(writer.write) == 'function')
end

--- Encode a form as application/x-www-form-urlencoded data.
--- @param form table Form fields to encode.
--- @param deeply? boolean Whether to traverse nested tables.
--- @param writer? form.urlencoded.writer Optional destination for encoded chunks.
--- @return string|integer|nil res Encoded string or bytes reported by the writer, or nil on failure.
--- @return any err Writer error or circular-reference error.
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
    elseif not pcall(check_writer, writer) then
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
