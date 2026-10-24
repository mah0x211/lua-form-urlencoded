local testcase = require('testcase')
local assert = require('assert')
local urlencoded = require('form.urlencoded')

function testcase.shallow_scalar_values()
    for _, value in ipairs({ 'hello world', 0, -42, 12.5, true, false }) do
        local expected = { value = { tostring(value) } }
        local encoded = assert(urlencoded.encode({ value = value }))
        assert.equal(assert(urlencoded.decode(encoded)), expected)
        encoded = assert(urlencoded.encode({ value = value }, false))
        assert.equal(assert(urlencoded.decode(encoded)), expected)
    end
end

function testcase.shallow_mixed_values_with_writer()
    local chunks = {}
    local writer = {
        write = function(_, s)
            chunks[#chunks + 1] = s
            return #s
        end,
    }
    local n = assert(urlencoded.encode({
        text = 'hello world',
        count = 0,
        enabled = true,
        disabled = false,
        items = { 'first', 42, false, name = 'not traversed' },
        nested = { name = 'not traversed' },
        [1] = 'ignored numeric root key',
    }, false, writer))
    local encoded = table.concat(chunks)
    assert.equal(n, #encoded)
    assert.equal(assert(urlencoded.decode(encoded)), {
        text = { 'hello world' },
        count = { '0' },
        enabled = { 'true' },
        disabled = { 'false' },
        items = { 'first', '42', 'false' },
    })
end
