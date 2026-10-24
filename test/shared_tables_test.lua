local testcase = require('testcase')
local assert = require('assert')
local urlencoded = require('form.urlencoded')

function testcase.shared_tables_on_separate_paths()
    local shared = {
        name = 'hello',
        values = {
            'first',
            42,
        },
    }
    local form = {
        left = {
            item = shared,
        },
        right = {
            item = shared,
        },
    }
    local expected = {
        ['left.item.name'] = {
            'hello',
        },
        ['left.item.values'] = {
            'first',
            '42',
        },
        ['right.item.name'] = {
            'hello',
        },
        ['right.item.values'] = {
            'first',
            '42',
        },
    }
    assert.equal(
        assert(urlencoded.decode(assert(urlencoded.encode(form, true)))),
        expected)

    local chunks = {}
    local writer = {
        write = function(_, s)
            chunks[#chunks + 1] = s
            return #s
        end,
    }
    local n = assert(urlencoded.encode(form, true, writer))
    local encoded = table.concat(chunks)
    assert.equal(n, #encoded)
    assert.equal(assert(urlencoded.decode(encoded)), expected)
end

function testcase.self_references_return_errors()
    local root = {
        name = 'root',
    }
    root.self = root
    local child = {}
    child.self = child
    local back = {}
    local parent = {
        child = back,
    }
    back.parent = parent
    local array = {}
    array[1] = array

    for _, case in ipairs({
        {
            root,
            'self',
        },
        {
            {
                child = child,
            },
            'child.self',
        },
        {
            parent,
            'child.parent',
        },
        {
            {
                items = array,
            },
            'items',
        },
    }) do
        local result, err = urlencoded.encode(case[1], true)
        assert.is_nil(result)
        assert.match(tostring(err), 'form.urlencoded.encode')
        assert.match(tostring(err), 'circular reference found at key ' ..
                         string.format('%q', case[2]))
    end

    -- A failed buffered call must not affect the next call.
    assert.equal(assert(urlencoded.encode({
        name = 'ok',
    }, true)), 'name=ok')
end

function testcase.mutual_references_return_errors()
    local left = {
        name = 'left',
    }
    local right = {
        name = 'right',
    }
    left.peer = right
    right.peer = left
    local result, err = urlencoded.encode({
        item = left,
    }, true)
    assert.is_nil(result)
    assert.match(tostring(err),
                 'circular reference found at key "item.peer.peer"')
end

function testcase.circular_reference_preserves_partial_writer_output()
    local child = {}
    child.self = child
    local chunks = {}
    local writer = {
        write = function(_, s)
            chunks[#chunks + 1] = s
            return #s
        end,
    }
    -- Both scalar entries are visited before the queued child, regardless
    -- of pairs order. One entry is written and the other is still buffered.
    local result, err = urlencoded.encode({
        first = 'one',
        second = 'two',
        child = child,
    }, true, writer)
    assert.is_nil(result)
    assert.match(tostring(err), 'circular reference found at key "child.self"')
    assert.equal(#chunks, 1)
    assert.equal(chunks[1] == 'first=one&' or chunks[1] == 'second=two&', true)
end

function testcase.shallow_encoding_does_not_traverse_cycles()
    local form = {
        name = 'root',
    }
    form.self = form
    assert.equal(assert(urlencoded.encode(form)), 'name=root')
end
