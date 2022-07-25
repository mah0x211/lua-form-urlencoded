# lua-form-urlencoded

[![test](https://github.com/mah0x211/lua-form-urlencoded/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-form-urlencoded/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-form-urlencoded/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-form-urlencoded)

encode/decode the application/x-www-form-urlencoded format.

***


## Installation

```
luarocks install form-urlencoded
```


## str = urlencoded.encode( form [, deeply] )

encode a table to www-form-urlencoded format string.

**Parameters**

- `form:table`: a table.
- `deeply:boolean`: `true` to deeply encode a table.

**Returns**

- `str:string`: a www-form-urlencoded string.


**Usage**


```lua
local urlencoded = require('form.urlencoded')

-- encode a table to www-form-urlencoded format string
local str = urlencoded.encode({
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
})
print(str) -- foo=hello+world!

-- deeply encode a table to www-form-urlencoded format string
str = urlencoded.encode({
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
}, true)
print(str) -- foo=hello+world!&bar.baz=123.5&bar.baa=true&bar.qux=hello&bar.qux=world&bar.qux.quux=value
```


## form, err = urlencoded.decode( str [, deeply] )

decode a table to www-form-urlencoded format string.

**Parameters**

- `form:table`: a table.
- `deeply:boolean`: `true` to deeply decode a www-form-urlencoded string.

**Returns**

- `form:table`: a table string.
- `err:any`: an error value.

**Usage**

```lua
local dump = require('dump')
local urlencoded = require('form.urlencoded')
local str = 'foo=hello+world!&bar.baz=123.5&bar.baa=true&bar.qux=hello&bar.qux=world&bar.qux.quux=value'

-- decode a www-form-urlencoded string to a table
local form = urlencoded.decode(str)
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

-- deeply decode a www-form-urlencoded string to a table
form = urlencoded.decode(str, true)
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

