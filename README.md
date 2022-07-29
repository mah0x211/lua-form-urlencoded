# lua-form-urlencoded

[![test](https://github.com/mah0x211/lua-form-urlencoded/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-form-urlencoded/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-form-urlencoded/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-form-urlencoded)

encode/decode the `application/x-www-form-urlencoded` format.

***


## Installation

```
luarocks install form-urlencoded
```


## n, err = urlencoded.encode( writer, form [, deeply] )

encode a form table to string in `application/x-www-form-urlencoded` format.

**Parameters**

- `writer:table|userdata`: call the `writer:write` method to output a string in `application/x-www-form-urlencoded` format.
    ```
    n, err = writer:write( s )
    - n:integer: number of bytes written.
    - err:any: error value.
    - s:string: output string.
    ```
- `form:table`: a table.
- `deeply:boolean`: `true` to deeply encode a table. (default: `false`)

**Returns**

- `n:integer`: total number of bytes written.
- `err:any`: error value.


**Usage**


```lua
local urlencoded = require('form.urlencoded')
local str
local writer = {
    write = function(_, s)
        str = str .. s
        return #s
    end,
}

-- encode a table to application/x-www-form-urlencoded format string
str = ''
local n = urlencoded.encode(writer, {
    foo = {
        'hello world!',
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
})
assert(n == #str)
print(str) -- foo=hello+world!

-- deeply encode a table to application/x-www-form-urlencoded format string
str = ''
n = urlencoded.encode(writer, {
    foo = {
        'hello world!',
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
}, true)
assert(n == #str)
print(str) -- foo=hello+world!&bar.baz=123.5&bar.baa=true&bar.qux=hello&bar.qux=world&bar.qux.quux=value
```


## form, err = urlencoded.decode( reader [, chunksize [, deeply]] )

decode a table to `application/x-www-form-urlencoded` format string.

**Parameters**

- `reader:table|userdata`: reads a string in `application/x-www-form-urlencoded` format with the `reader:read` method.
    ```
    s, err = reader:read( n )
    - n:integer: number of bytes read.
    - s:string: a string in application/x-www-form-urlencoded format.
    - err:any: error value.
    ```
- `chunksize:integer`: number of byte to read from the `reader.read` method. this value must be greater than `0`. (default: `4096`)
- `deeply:boolean`: `true` to deeply decode a `application/x-www-form-urlencoded` string.

**Returns**

- `form:table`: a table string.
- `err:any`: an error value.

**Usage**

```lua
local dump = require('dump')
local urlencoded = require('form.urlencoded')
local data = 'foo=hello+world!&bar.baz=123.5&bar.baa=true&bar.qux=hello&bar.qux=world&bar.qux.quux=value'
local str
local reader = {
    read = function(_, n)
        if #str > 0 then
            local s = string.sub(str, 1, n)
            str = string.sub(str, n + 1)
            return s
        end
    end,
}
-- decode a application/x-www-form-urlencoded string to a table
str = data
local form = urlencoded.decode(reader)
print(dump(form))
-- {
--     ["bar.baa"] = {
--         [1] = "true"
--     },
--     ["bar.baz"] = {
--         [1] = "123.5"
--     },
--     ["bar.qux"] = {
--         [1] = "hello",
--         [2] = "world"
--     },
--     ["bar.qux.quux"] = {
--         [1] = "value"
--     },
--     foo = {
--         [1] = "hello world!"
--     }
-- }

-- deeply decode a application/x-www-form-urlencoded string to a table
str = data
form = urlencoded.decode(reader, nil, true)
print(dump(form))
-- {
--     bar = {
--         baa = {
--             [1] = "true"
--         },
--         baz = {
--             [1] = "123.5"
--         },
--         qux = {
--             [1] = "hello",
--             [2] = "world",
--             quux = {
--                 [1] = "value"
--             }
--         }
--     },
--     foo = {
--         [1] = "hello world!"
--     }
-- }
```

