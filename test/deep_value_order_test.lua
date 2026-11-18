local testcase = require('testcase')
local assert = require('assert')
local urlencoded = require('form.urlencoded')

function testcase.deep_encoding_orders_scalar_values_by_integer_key()
    assert.equal(assert(urlencoded.encode({
        items = {
            [2] = 'second',
            [1] = 'first',
        },
    }, true)), 'items=first&items=second')
end

function testcase.deep_encoding_orders_sibling_tables()
    assert.equal(assert(urlencoded.encode({
        items = {
            { name = 'first' },
            { name = 'second' },
        },
    }, true)), 'items.name=first&items.name=second')
end

function testcase.deep_encoding_orders_sparse_mixed_values()
    local chunks = {}
    local writer = {
        write = function(_, s)
            chunks[#chunks + 1] = s
            return #s
        end,
    }
    local expected = 'items=first&items=second&items=third'
    local n = assert(urlencoded.encode({
        items = {
            [-2] = 'first',
            [0] = { 'second' },
            [5] = 'third',
        },
    }, true, writer))
    assert.equal(table.concat(chunks), expected)
    assert.equal(n, #expected)
end
