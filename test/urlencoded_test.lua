require('luacov')
local testcase = require('testcase')
local assert = require('assert')
local urlencoded = require('form.urlencoded')

function testcase.encode()
    local form = {
        foo = {
            'hello world!',
        },
        hello = 'world',
        bar = {
            baa = true,
            baz = 123.5,
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

    -- test that encode form table to string
    local str = assert(urlencoded.encode(form))
    assert.is_string(str)
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
    str = assert(urlencoded.encode(form, true))
    assert.is_string(str)
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
    str = assert(urlencoded.encode({
        'hello',
        bar = {
            qux = {},
        },
    }, true))
    assert.is_string(str)
    assert.equal(#str, 0)

    -- test that throws an error if form argument is invalid
    local err = assert.throws(urlencoded.encode, 'hello')
    assert.match(err, 'form must be table')

    -- test that throws an error if deeply argument is invalid
    err = assert.throws(urlencoded.encode, {}, 'hello')
    assert.match(err, 'deeply must be boolean')
end

function testcase.encode_with_writer()
    local form = {
        foo = {
            'hello world!',
        },
        hello = 'world',
        bar = {
            baa = true,
            baz = 123.5,
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
    local n = assert(urlencoded.encode(form, nil, writer))
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
    n = assert(urlencoded.encode(form, true, writer))
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
    n = assert(urlencoded.encode({
        'hello',
        bar = {
            qux = {},
        },
    }, true, writer))
    assert.equal(n, 0)
    assert.equal(n, #str)

    -- test that error from writer
    str = ''
    local err
    n, err = urlencoded.encode({
        hello = {
            'world',
        },
    }, nil, {
        write = function()
            return nil, 'write error'
        end,
    })
    assert.is_nil(n, 0)
    assert.match(err, 'write error')

    -- test that throws an error if form argument is invalid
    err = assert.throws(urlencoded.encode, 'hello')
    assert.match(err, 'form must be table')

    -- test that throws an error if deeply argument is invalid
    err = assert.throws(urlencoded.encode, {}, 'hello')
    assert.match(err, 'deeply must be boolean')

    -- test that throws an error if writer argument is invalid
    err = assert.throws(urlencoded.encode, {
        hello = {
            'world',
        },
    }, nil, 'world')
    assert.match(err, 'writer.write must be function')
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

    -- test that decode form string into table
    local tbl = assert(urlencoded.decode(data))
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
    tbl = assert(urlencoded.decode(data, true))
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

    -- test that throws an error if first argument is not string
    local err = assert.throws(urlencoded.decode, true)
    assert.match(err, 'chunk must be string')

    -- test that throws an error if deeply argument is not boolean
    err = assert.throws(urlencoded.decode, '', 'true')
    assert.match(err, 'deeply must be boolean')
end

function testcase.decode_with_reader()
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
    tbl = assert(urlencoded.decode(reader, true, 2))
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
    assert.match(err, 'chunk must be string or it must have read method')

    -- test that throws an error if chunksize is not uint
    err = assert.throws(urlencoded.decode, reader, nil, true)
    assert.match(err, 'chunksize must be uint greater than 0')
end

