local testcase = require('testcase')
local assert = require('assert')
local errlib = require('error')
local urlencoded = require('form.urlencoded')
local default_size = 128 * 1024

local function reader(input)
    local source = {pos=1, requests={}}
    function source:read(n)
        self.requests[#self.requests + 1] = n
        local s = input:sub(self.pos, self.pos + n - 1)
        self.pos = self.pos + #s
        if #s > 0 then return s end
    end
    return source
end

local function assert_exceeded(form, err)
    assert.is_nil(form)
    assert.equal(errlib.typeof(err).name, 'form.urlencoded.decode')
    assert.match(tostring(err), 'maxsize')
end

function testcase.decode_counts_raw_bytes_before_percent_decoding()
    local input = ' a=%41&&b=+ '
    for _, source in ipairs({ input, reader(input) }) do
        local form, err = urlencoded.decode(source, {maxsize=#input})
        assert.is_nil(err)
        assert.equal(form, {a={'A'}, b={' '}})
    end
    assert_exceeded(urlencoded.decode(input, {maxsize=#input - 1}))
    assert_exceeded(urlencoded.decode('a=%', {maxsize=2}))
end

function testcase.decode_applies_total_limits_across_reader_chunks()
    local input = 'a=%41&&b=two+words'
    for _, size in ipairs({1, 2, 7, 4096}) do
        local source = reader(input)
        local form, err = urlencoded.decode(source, {
            maxsize=#input, chunksize=size, deeply=true,
        })
        assert.is_nil(err)
        assert.equal(form, {a={'A'}, b={'two words'}})
        assert.equal(source.pos, #input + 1)
        assert_exceeded(urlencoded.decode(reader(input .. '&'), {
            maxsize=#input, chunksize=size,
        }))
    end
end

function testcase.decode_defaults_named_options_to_128kb()
    local input = 'x=' .. string.rep('a', default_size - 2)
    for _, source in ipairs({input, reader(input)}) do
        local form, err = urlencoded.decode(source, {})
        assert.is_nil(err)
        assert.equal(#form.x[1], default_size - 2)
    end
    for _, source in ipairs({input .. 'a', reader(input .. 'a')}) do
        assert_exceeded(urlencoded.decode(source, {}))
    end
end

function testcase.decode_keeps_legacy_calls_unlimited()
    local input = 'x=' .. string.rep('a', default_size)
    local form, err = urlencoded.decode(input)
    assert.is_nil(err)
    assert.equal(#form.x[1], default_size)
    form, err = urlencoded.decode(reader(input), nil, 4096)
    assert.is_nil(err)
    assert.equal(#form.x[1], default_size)
end

function testcase.decode_accepts_explicit_limits_above_default_and_infinity()
    local input = 'x=' .. string.rep('a', default_size)
    for _, maxsize in ipairs({#input, math.huge}) do
        local opts = {maxsize=maxsize}
        for _, source in ipairs({input, reader(input)}) do
            local form, err = urlencoded.decode(source, opts)
            assert.is_nil(err)
            assert.equal(#form.x[1], default_size)
        end
        assert.equal(opts, {maxsize=maxsize})
    end
end

function testcase.decode_zero_and_negative_limits_accept_only_empty_input()
    for _, maxsize in ipairs({0, -1, -100}) do
        for _, source in ipairs({'', reader('')}) do
            local form, err = urlencoded.decode(source, {maxsize=maxsize})
            assert.is_nil(err)
            assert.empty(form)
        end
        for _, source in ipairs({'&', reader('&')}) do
            assert_exceeded(urlencoded.decode(source, {maxsize=maxsize}))
        end
    end
end

function testcase.decode_limits_read_requests_to_remaining_budget_plus_one()
    local source = reader('a=b')
    local form, err = urlencoded.decode(source, {maxsize=3, chunksize=4096})
    assert.is_nil(err)
    assert.equal(form, {a={'b'}})
    assert.equal(source.requests, {4, 1})

    source = reader('a=bc')
    assert_exceeded(urlencoded.decode(source, {maxsize=3, chunksize=4096}))
    assert.equal(source.requests, {4})
    assert.equal(source.pos, 5)
end

function testcase.decode_counts_actual_reader_bytes_if_request_is_exceeded()
    local calls = 0
    assert_exceeded(urlencoded.decode({
        read=function(_, n)
            calls = calls + 1
            assert.equal(n, 4)
            return 'a=unexpectedly large'
        end,
    }, {maxsize=3}))
    assert.equal(calls, 1)
end

function testcase.decode_invalid_maxsize_raises_before_reading()
    local calls = 0
    for _, maxsize in ipairs({false, true, '3', {}, 1.5, -1.5, -math.huge, 0/0}) do
        local ok, err = pcall(urlencoded.decode, {
            read=function() calls = calls + 1 end,
        }, {maxsize=maxsize})
        assert.is_false(ok)
        assert.match(tostring(err), 'maxsize must be integer or math.huge')
    end
    assert.equal(calls, 0)
end

function testcase.decode_preserves_reader_errors_with_partial_oversized_data()
    local cause = {}
    local form, err = urlencoded.decode({
        read=function() return 'a=too large', cause end,
    }, {maxsize=0})
    assert.is_nil(form)
    assert.rawequal(err, cause)
end

function testcase.decode_infinity_keeps_requested_read_size()
    local source = reader('a=b')
    local form, err = urlencoded.decode(source, {maxsize=math.huge, chunksize=2})
    assert.is_nil(err)
    assert.equal(form, {a={'b'}})
    assert.equal(source.requests, {2, 2, 2})
end
