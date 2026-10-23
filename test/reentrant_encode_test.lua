local testcase = require('testcase')
local assert = require('assert')
local urlencoded = require('form.urlencoded')

-- Lua 5.1 does not invoke __pairs; exercise this path on newer runtimes.
if _VERSION ~= 'Lua 5.1' then
    function testcase.reentrant_encode_empty_form()
        for _, deeply in ipairs({ false, true }) do
            local inner
            local form = setmetatable({}, {
                __pairs = function()
                    inner = assert(urlencoded.encode({ inner = 'value' }, deeply))
                    return next, {}, nil
                end,
            })
            assert.equal(assert(urlencoded.encode(form, deeply)), '')
            assert.equal(inner, 'inner=value')
        end
    end

    function testcase.reentrant_encode_preserves_pending_and_written_values()
        for _, deeply in ipairs({ false, true }) do
            local calls = 0
            local form = setmetatable({}, {
                __pairs = function()
                    local i = 0
                    return function()
                        i = i + 1
                        if i <= 3 then
                            -- The second entry flushes the first entry before
                            -- the third iterator call reenters encode.
                            assert.equal(assert(urlencoded.encode({ inner = 'value' },
                                                                  not deeply)),
                                         'inner=value')
                            calls = calls + 1
                            return 'key' .. i, 'value' .. i
                        end
                    end
                end,
            })
            local encoded = assert(urlencoded.encode(form, deeply))
            assert.equal(calls, 3)
            assert.equal(encoded, 'key1=value1&key2=value2&key3=value3')
        end
    end
end
