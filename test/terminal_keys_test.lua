local testcase = require('testcase')
local assert = require('assert')
local urlencoded = require('form.urlencoded')

function testcase.single_character_terminal_keys()
    for _, case in ipairs({
        { 'a=v', { a = { 'v' } } },
        { 'foo.a=v', { foo = { a = { 'v' } } } },
        { 'foo.a.b=v', { foo = { a = { b = { 'v' } } } } },
    }) do
        assert.equal(assert(urlencoded.decode(case[1], true)), case[2])
    end
end

function testcase.empty_terminal_keys()
    for _, case in ipairs({
        { 'foo.=v', { foo = { [''] = { 'v' } } } },
        { 'foo...=v', { foo = { [''] = { [''] = { [''] = { 'v' } } } } } },
        { '.=v', { [''] = { [''] = { 'v' } } } },
        { 'foo%2E=v', { foo = { [''] = { 'v' } } } },
        { 'foo.', { foo = { [''] = { '' } } } },
    }) do
        assert.equal(assert(urlencoded.decode(case[1], true)), case[2])
    end
end

function testcase.leading_and_intermediate_empty_keys()
    assert.equal(assert(urlencoded.decode('.foo=v', true)), {
        [''] = { foo = { 'v' } },
    })
    assert.equal(assert(urlencoded.decode('foo..bar=v', true)), {
        foo = { [''] = { bar = { 'v' } } },
    })
    assert.equal(assert(urlencoded.decode('.foo.=v', true)), {
        [''] = { foo = { [''] = { 'v' } } },
    })
end

function testcase.repeated_terminal_keys()
    assert.equal(assert(urlencoded.decode('foo=v&foo.=w&foo.=x&foo.a=y&foo.a=z', true)), {
        foo = { 'v', [''] = { 'w', 'x' }, a = { 'y', 'z' } },
    })
end

function testcase.terminal_keys_with_reader()
    local input = 'a=v&foo.=w&foo...=x&foo.a=y&.foo.=z'
    local expected = {
        a = { 'v' },
        foo = { [''] = { 'w', [''] = { [''] = { 'x' } } }, a = { 'y' } },
        [''] = { foo = { [''] = { 'z' } } },
    }
    for size = 1, 4 do
        local pos = 1
        local reader = {
            read = function(_, n)
                if pos > #input then return nil end
                local chunk = input:sub(pos, pos + n - 1)
                pos = pos + #chunk
                return chunk
            end,
        }
        assert.equal(assert(urlencoded.decode(reader, true, size)), expected)
    end
end

function testcase.empty_terminal_key_round_trip()
    local value = { foo = { [''] = { 'v' } } }
    local encoded = assert(urlencoded.encode(value, true))
    assert.equal(encoded, 'foo.=v')
    assert.equal(assert(urlencoded.decode(encoded, true)), value)
end

function testcase.shallow_keys_and_empty_whole_names()
    assert.equal(assert(urlencoded.decode('foo.=v&foo...=w')), {
        ['foo.'] = { 'v' }, ['foo...'] = { 'w' },
    })
    assert.equal(assert(urlencoded.decode('=v', true)), {})
end
