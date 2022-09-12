require('luacov')
local testcase = require('testcase')
local urlencoded = require('form.urlencoded')

function testcase.encode()
    local form = {
        foo = {
            'hello world!',
        },
        hello = {
            'world',
        },
        bar = {
            baa = {
                true,
            },
            baz = {
                123.5,
            },
            qux = {
                'hello',
                'world',
                quux = {
                    'value',
                },
            },
        },
        multiline = {
            'multi/\nline',
        },
    }
    local str
    local writer = {
        write = function(_, s)
            str = str .. s
            return #s
        end,
    }

    -- test that encode form table to string
    str = ''
    local n = assert(urlencoded.encode(writer, form))
    assert.equal(n, #str)
    local kvpairs = {}
    for kv in string.gmatch(str, '([^&]+)') do
        kvpairs[#kvpairs + 1] = kv
    end
    table.sort(kvpairs)
    assert.equal(kvpairs, {
        'foo=hello+world%21',
        'hello=world',
        'multiline=multi%2F%0Aline',
    })

    -- test that encode form table to string deeply
    str = ''
    n = assert(urlencoded.encode(writer, form, true))
    assert.equal(n, #str)
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
        'foo=hello+world%21',
        'hello=world',
        'multiline=multi%2F%0Aline',
    })

    -- test that return empty-string
    str = ''
    n = assert(urlencoded.encode(writer, {
        'hello',
        bar = {
            qux = {},
        },
    }, true))
    assert.equal(n, 0)
    assert.equal(n, #str)

    -- test that error from writer
    str = ''
    local err
    n, err = urlencoded.encode({
        write = function()
            return nil, 'write error'
        end,
    }, {
        hello = {
            'world',
        },
    })
    assert.is_nil(n, 0)
    assert.match(err, 'write error')

    -- test that throws an error if writer argument is invalid
    err = assert.throws(urlencoded.encode, 'hello')
    assert.match(err, 'writer.write must be function')

    -- test that throws an error if form argument is invalid
    err = assert.throws(urlencoded.encode, writer, 'hello')
    assert.match(err, 'form must be table')

    -- test that throws an error if deeply argument is invalid
    err = assert.throws(urlencoded.encode, writer, {}, 'hello')
    assert.match(err, 'deeply must be boolean')
end

function testcase.decode()
    local data = table.concat({
        -- key/val pair
        'foo=hello+world%21',
        'multiline=multi%2F%0Aline',
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
        -- last data
        'last-key=last-value',
    }, '&')
    local str = data
    local reader = {
        read = function(_, n)
            if #str > 0 then
                local s = string.sub(str, 1, n)
                str = string.sub(str, n + 1)
                return s
            end
        end,
    }

    -- test that decode form string into table
    str = data
    local tbl = assert(urlencoded.decode(reader))
    assert.equal(tbl, {
        foo = {
            'hello world!',
        },
        multiline = {
            'multi/\nline',
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
        ['last-key'] = {
            'last-value',
        },
    })

    -- test that decode form string into table deeply
    str = data
    tbl = assert(urlencoded.decode(reader, 2, true))
    assert.equal(tbl, {
        foo = {
            'hello world!',
        },
        multiline = {
            'multi/\nline',
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
        ['last-key'] = {
            'last-value',
        },
    })

    -- test that return empty-table
    tbl = assert(urlencoded.decode(reader))
    assert.empty(tbl)

    for _, v in ipairs({
        'fo%0o',
        'fo%0o=bar',
        'foo=ba%r',
    }) do
        -- test that EILSEQ if invalid character found in key
        str = v
        local _, err = urlencoded.decode(reader)
        assert.match(err, 'illegal character "%" found')
    end

    -- test that error from reader
    str = data
    local err
    tbl, err = urlencoded.decode({
        read = function()
            return nil, 'read error'
        end,
    })
    assert.is_nil(tbl)
    assert.match(err, 'read error')

    -- test that throws an error if reader.read is not function
    err = assert.throws(urlencoded.decode, {})
    assert.match(err, 'reader.read must be function')

    -- test that throws an error if chunksize is not uint
    err = assert.throws(urlencoded.decode, reader, true)
    assert.match(err, 'chunksize must be uint greater than 0')

    -- test that throws an error if deeply argument is not boolean
    err = assert.throws(urlencoded.decode, reader, nil, 'true')
    assert.match(err, 'deeply must be boolean')
end

