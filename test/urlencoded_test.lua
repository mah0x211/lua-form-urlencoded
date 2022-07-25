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
    local str = table.concat({
        -- key/val pair
        'foo=hello+world!',
        -- empty
        '',
        ' ',
        -- multiple keys
        'bar.qux=hello',
        'bar.qux=world',
        -- nested key
        'bar.qux.quux=value',
        -- with spaces
        '  \thello=world \t ',
        -- key only
        'key',
        -- with no value
        'no-value=',
        -- with no key
        '=no-key',
        -- only spaces
        '  \t \t  ',
    }, '&')

    -- test that decode form string into table
    local tbl = assert(urlencoded.decode(str))
    assert.equal(tbl, {
        foo = {
            'hello world!',
        },
        ['bar.qux'] = {
            'hello',
            'world',
        },
        ['bar.qux.quux'] = {
            'value',
        },
        ['hello'] = {
            'world',
        },
        key = {
            '',
        },
        ['no-value'] = {
            '',
        },
    })

    -- test that decode form string into table deeply
    tbl = assert(urlencoded.decode(str, true))
    assert.equal(tbl, {
        foo = {
            'hello world!',
        },
        bar = {
            qux = {
                'hello',
                'world',
                quux = {
                    'value',
                },
            },
        },
        hello = {
            'world',
        },
        key = {
            '',
        },
        ['no-value'] = {
            '',
        },
    })

    -- test that return empty-table
    tbl = assert(urlencoded.decode(''))
    assert.empty(tbl)

    for _, v in ipairs({
        'fo%0o',
        'fo%0o=bar',
        'foo=ba%r',
    }) do
        -- test that EILSEQ if invalid character found in key
        local _, err = urlencoded.decode(v)
        assert.match(err, 'illegal character "%" found')
    end

    -- test that throws an error if str argument is not string
    local err = assert.throws(urlencoded.decode, true)
    assert.match(err, 'str must be string')

    -- test that throws an error if deeply argument is not boolean
    err = assert.throws(urlencoded.decode, '', {})
    assert.match(err, 'deeply must be boolean')
end

