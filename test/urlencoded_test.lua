require('luacov')
local testcase = require('testcase')
local urlencoded = require('form.urlencoded')

function testcase.encode()
    local form = {
        foo = 'hello world!',
        bar = {
            baa = true,
            baz = 123.5,
            qux = {
                'hello',
                'world',
                quux = 'value',
            },
        },
    }

    -- test that encode form table to string
    local str = assert(urlencoded.encode(form))
    local kvpairs = {}
    for kv in string.gmatch(str, '([^&]+)') do
        kvpairs[#kvpairs + 1] = kv
    end
    assert.equal(kvpairs, {
        'foo=hello+world!',
    })

    -- test that encode form table to string deeply
    str = assert(urlencoded.encode(form, true))
    kvpairs = {}
    for kv in string.gmatch(str, '([^&]+)') do
        kvpairs[#kvpairs + 1] = kv
    end
    table.sort(kvpairs)
    assert.equal(kvpairs, {
        'bar.baa=true',
        'bar.baz=123.5',
        'bar.qux.quux=value',
        'bar.qux=hello',
        'bar.qux=world',
        'foo=hello+world!',
    })

    -- test that return empty-string
    str = assert(urlencoded.encode({
        'hello',
        bar = {
            qux = {},
        },
    }, true))
    assert.equal(str, '')

    -- test that throws an error if form argument is not table
    local err = assert.throws(urlencoded.encode, 'hello')
    assert.match(err, 'form must be table')

    -- test that throws an error if deeply argument is not boolean
    err = assert.throws(urlencoded.encode, {}, 'hello')
    assert.match(err, 'deeply must be boolean')
end

function testcase.decode()
    -- test that decode form string into table
    local tbl = assert(urlencoded.decode(
                           'foo=hello+world!&bar.qux=hello&bar.qux=world&bar.qux.quux=value&bar.baa=true&bar.baz=123.5'))
    assert.equal(tbl, {
        foo = {
            'hello world!',
        },
        ['bar.baa'] = {
            'true',
        },
        ['bar.baz'] = {
            '123.5',
        },
        ['bar.qux'] = {
            'hello',
            'world',
        },
        ['bar.qux.quux'] = {
            'value',
        },
    })

    -- test that decode form string into table deeply
    tbl = assert(urlencoded.decode(
                     'foo=hello+world!&bar.qux=hello&bar.qux=world&bar.qux.quux=value&bar.baa=true&bar.baz=123.5',
                     true))
    assert.equal(tbl, {
        foo = {
            'hello world!',
        },
        bar = {
            baa = {
                'true',
            },
            baz = {
                '123.5',
            },
            qux = {
                'hello',
                'world',
                quux = {
                    'value',
                },
            },
        },
    })

    -- test that return empty-table
    tbl = assert(urlencoded.decode(''))
    assert.empty(tbl)

    -- test that throws an error if str argument is not string
    local err = assert.throws(urlencoded.decode, true)
    assert.match(err, 'str must be string')

    -- test that throws an error if deeply argument is not boolean
    err = assert.throws(urlencoded.decode, '', {})
    assert.match(err, 'deeply must be boolean')
end

