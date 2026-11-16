local testcase = require('testcase')
local assert = require('assert')
local urlencoded = require('form.urlencoded')
local unpack = table.unpack or unpack

local function reader(input, expected_size)
    local pos = 1
    return {
        read = function(_, n)
            assert.equal(n, expected_size)
            local s = input:sub(pos, pos + n - 1)
            pos = pos + #s
            if #s > 0 then return s end
        end,
    }
end

function testcase.decode_named_options_default_to_shallow_decoding()
    local input = 'a.b=x&a.b=y&flag&plus=a+b'
    local expected = {
        ['a.b'] = { 'x', 'y' }, flag = { '' }, plus = { 'a b' },
    }
    for _, chunk in ipairs({ input, reader(input, 4096) }) do
        local opts = {}
        local form, err = urlencoded.decode(chunk, opts)
        assert.is_nil(err)
        assert.equal(form, expected)
        assert.empty(opts)
    end
end

function testcase.decode_named_options_select_deep_decoding_and_read_size()
    local input = 'a.b=x&a.b=y&flag&plus=a+b'
    local expected = {
        a = { b = { 'x', 'y' } }, flag = { '' }, plus = { 'a b' },
    }
    for _, size in ipairs({ 1, 2, 7, 4096 }) do
        local opts = { deeply = true, chunksize = size, unsupported = 'ignored' }
        for _, chunk in ipairs({ input, reader(input, size) }) do
            local form, err = urlencoded.decode(chunk, opts)
            assert.is_nil(err)
            assert.equal(form, expected)
        end
        assert.equal(opts, { deeply = true, chunksize = size, unsupported = 'ignored' })
    end
end

function testcase.decode_named_options_preserve_explicit_shallow_mode()
    local opts = { deeply = false, chunksize = 1 }
    local form, err = urlencoded.decode(reader('a.b=x', 1), opts)
    assert.is_nil(err)
    assert.equal(form, { ['a.b'] = { 'x' } })
    assert.equal(opts, { deeply = false, chunksize = 1 })
end

function testcase.decode_preserves_legacy_nil_arguments_and_extra_arguments()
    for _, args in ipairs({
        {n=0}, {n=1}, {n=1, false}, {n=2, [2]=2},
        {n=3, [2]=2, [3]={ deeply=true }},
    }) do
        local size = args[2] or 4096
        local form, err = urlencoded.decode(reader('a.b=x', size),
                                           unpack(args, 1, args.n))
        assert.is_nil(err)
        assert.equal(form, { ['a.b'] = { 'x' } })
    end
    local form, err = urlencoded.decode(reader('a.b=x', 2), true, 2)
    assert.is_nil(err)
    assert.equal(form, { a = { b = { 'x' } } })
end

function testcase.decode_multiple_optional_arguments_remain_positional()
    local ok, err = pcall(urlencoded.decode, 'a=x', {}, nil)
    assert.is_false(ok)
    assert.match(tostring(err), 'deeply must be boolean')
end

function testcase.decode_ignores_read_size_for_string_input()
    for _, size in ipairs({ false, 0, -1, 1.5, 'bad', {} }) do
        local form, err = urlencoded.decode('a=x', { chunksize=size })
        assert.is_nil(err)
        assert.equal(form, { a = { 'x' } })
        form, err = urlencoded.decode('a=x', nil, size)
        assert.is_nil(err)
        assert.equal(form, { a = { 'x' } })
    end
end

function testcase.decode_rejects_invalid_named_options_before_reading()
    local calls = 0
    local source = {read=function() calls = calls + 1 end}
    for _, deeply in ipairs({ 0, 'true', {}, function() end }) do
        local ok, err = pcall(urlencoded.decode, source, { deeply=deeply })
        assert.is_false(ok)
        assert.match(tostring(err), 'deeply must be boolean')
    end
    for _, size in ipairs({ false, 0, -1, 1.5, '2', {}, math.huge }) do
        local ok, err = pcall(urlencoded.decode, source, { chunksize=size })
        assert.is_false(ok)
        assert.match(tostring(err), 'chunksize must be uint greater than 0')
    end
    assert.equal(calls, 0)
end

function testcase.decode_named_options_preserve_reader_errors()
    local cause = {}
    local calls = 0
    local form, err = urlencoded.decode({
        read=function(_, n)
            calls = calls + 1
            assert.equal(n, 3)
            return nil, cause
        end,
    }, {deeply=true, chunksize=3})
    assert.is_nil(form)
    assert.rawequal(err, cause)
    assert.equal(calls, 1)
end
