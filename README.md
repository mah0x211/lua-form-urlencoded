# lua-form-urlencoded

[![test](https://github.com/mah0x211/lua-form-urlencoded/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-form-urlencoded/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-form-urlencoded/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-form-urlencoded)

encode/decode the `application/x-www-form-urlencoded` format.

***


## Installation

```
luarocks install form-urlencoded
```


## res, err = urlencoded.encode( form [, deeply [, writer]] )

encode a form table to string in `application/x-www-form-urlencoded` format.

**Parameters**

- `form:table`: a table.
- `deeply:boolean`: `true` to deeply encode a table. (default: `false`)
- `writer:table|userdata`: call the `writer:write` method to output a string in `application/x-www-form-urlencoded` format.
    ```
    n, err = writer:write( s )
    - n:integer: number of bytes written.
    - err:any: error value.
    - s:string: output string.
    ```

**Returns**

- `res:string|integer`: a string in `application/x-www-form-urlencoded` format, or number of bytes written.
  - if the `writer` parameter is not specified, it returns a string in `application/x-www-form-urlencoded` format.
  - otherwise, it returns the number of bytes written to the `writer:write` method.
- `err:any`: error value.


**NOTE:**

the supported value types are `string`, `number`, `boolean`, and `table`. if the value is a table, it will be encoded each value as multiple values like the following example.

```
{
    key = {
        'value-1',
        'value-2',
    }
}

```

will be encoded as

```
key=value-1&key=value-2
```

it encodes only the first level of the table by default. if you want to encode deeply, set the `deeply` parameter to `true`.


**Usage**


```lua
local urlencoded = require('form.urlencoded')

-- encode a table to application/x-www-form-urlencoded format string
local str = urlencoded.encode({
    hello = 'world',
    foo = {
        'value-1',
        'value-2',
    },
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
})
print(str) -- hello=world&foo=value-1&foo=value-2

-- encode a table to application/x-www-form-urlencoded format string
str = urlencoded.encode({
    hello = 'world',
    foo = {
        'value-1',
        'value-2',
    },
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
}, true)
print(str) -- hello=world&bar.baa=true&bar.baz=123.5&bar.qux=hello&bar.qux=world&bar.qux.quux=value&foo=value-1&foo=value-2
```


## form, err = urlencoded.decode( reader [, deeply [, chunksize]] )

decode a string in `application/x-www-form-urlencoded` format into a table.

**Parameters**

- `reader:string|table|userdata`: a string in `application/x-www-form-urlencoded` format.
    - if the `reader` parameter is not a string, it must have a `reader.read` method.
      ```
      s, err = reader:read( n )
      - n:integer: number of bytes read.
      - s:string: a string in application/x-www-form-urlencoded format.
      - err:any: error value.
      ```
- `deeply:boolean`: `true` to deeply decode a `application/x-www-form-urlencoded` string.
- `chunksize:integer`: if the `reader` parameter is not a string, number of byte to read from the `reader.read` method. this value must be greater than `0`. (default: `4096`)

**Returns**

- `form:table`: a table contains the decoded values.
- `err:any`: an error value.

**Usage**

```lua
local dump = require('dump')
local urlencoded = require('form.urlencoded')
local data =
    'foo=hello+world!&bar.baz=123.5&bar.baa=true&bar.qux=hello&bar.qux=world&bar.qux.quux=value'

-- decode a application/x-www-form-urlencoded string to a table
local form = urlencoded.decode(data)
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
form = urlencoded.decode(data, true)
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

