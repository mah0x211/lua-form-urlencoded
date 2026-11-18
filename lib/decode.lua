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
local find = string.find
local format = string.format
local sub = string.sub
local match = string.match
local pcall = pcall
local select = select
local type = type
local huge = math.huge
local is = require('lauxhlib.is')
local is_int = is.int
local is_uint = is.uint
local decode_form = require('url').decode_form
local DEFAULT_MAX_SIZE = 128 * 1024
local EDECODE = require('error').type.new('form.urlencoded.decode', nil,
                                          'form-urlencoded decode error')

--- push2form
--- @param form table
--- @param key string
--- @param val string
--- @param deeply? boolean
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

        local k = sub(key, pos)
        local child = list[k]
        if not child then
            child = {}
            list[k] = child
        end
        list = child
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
--- @return string? v
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
--- @param deeply? boolean
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

--- Normalize options without modifying caller-owned tables.
--- @param has_reader boolean
--- @param ... table|boolean|integer|nil Options or legacy deeply, chunksize.
--- @return table opts
local function checkopts(has_reader, ...)
    local narg = select('#', ...)
    local deeply, chunksize = ...
    local opts = deeply
    local noopts = narg > 1 or type(deeply) ~= 'table'
    if noopts then
        opts = {
            deeply = deeply,
            chunksize = chunksize,
        }
    end

    chunksize = opts.chunksize
    if has_reader then
        if chunksize == nil then
            chunksize = 4096
        elseif not is_uint(chunksize) or chunksize < 1 then
            error('chunksize must be uint greater than 0', 3)
        end
    end

    deeply = opts.deeply
    if deeply ~= nil and type(deeply) ~= 'boolean' then
        error('deeply must be boolean', 3)
    end

    local maxsize = opts.maxsize
    if noopts then
        maxsize = huge
    elseif maxsize == nil then
        maxsize = DEFAULT_MAX_SIZE
    elseif maxsize ~= huge and not is_int(maxsize) then
        error('maxsize must be integer or math.huge', 3)
    elseif maxsize < 0 then
        maxsize = 0
    end

    return {
        deeply = deeply,
        chunksize = chunksize,
        maxsize = maxsize,
    }
end

--- @class form.urlencoded.reader
--- @field read fun(self, n:integer):(s:string?,err:any)

--- decode
--- @param chunk string|form.urlencoded.reader
--- @param ... table|boolean|integer|nil Options or legacy deeply, chunksize.
--- @return table? form
--- @return any err
local function decode(chunk, ...)
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
    end

    local opts = checkopts(no_read, ...)
    local deeply = opts.deeply
    local chunksize = opts.chunksize
    local maxsize = opts.maxsize
    local nread = #str
    if nread > maxsize then
        return nil, EDECODE:new('form-urlencoded body exceeds maxsize')
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

        -- Read at most one byte beyond the remaining budget to distinguish
        -- exact-limit EOF from oversized input.
        local n = chunksize
        local remaining = maxsize - nread
        if remaining < n then
            n = remaining + 1
        end
        local s, err = chunk:read(n)
        if err then
            return nil, err
        elseif not s or #s == 0 then
            break
        end
        -- Count received bytes before decoding or trimming any of them.
        nread = nread + #s
        if nread > maxsize then
            return nil, EDECODE:new('form-urlencoded body exceeds maxsize')
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
    decode = decode,
}
