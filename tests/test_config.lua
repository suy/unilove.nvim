local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local config = require('unilove.config')

local T = new_set({
    hooks = {
        -- Restore to the defaults each time.
        pre_case = function()
            config.setup()
        end,
    },
})

T['setup()'] = new_set()

T['setup()']['uses the documented defaults'] = function()
    eq(config.unicode_data_path, nil)
    eq(config.format, nil)
    eq(config.separator, '\t')
    eq(config.show_digraphs, false)
    eq(config.show_html_entities, false)
    eq(config.show_name, true)
    eq(config.show_octal, false)
end

T['setup()']['sets values whose defaults are nil'] = function()
    local format = function() end
    config.setup({ unicode_data_path = '/tmp/UnicodeData.txt', format = format })

    eq(config.unicode_data_path, '/tmp/UnicodeData.txt')
    eq(config.format, format)
end

T['setup()']['resets omitted values to their defaults'] = function()
    config.setup({ show_octal = true, separator = ' | ' })
    config.setup({ show_name = false })

    eq(config.show_octal, false)
    eq(config.separator, '\t')
    eq(config.show_name, false)
end

T['setup()']['resets nil-valued defaults when called without options'] = function()
    config.setup({ unicode_data_path = '/tmp/UnicodeData.txt', format = function() end })
    config.setup()

    eq(config.unicode_data_path, nil)
    eq(config.format, nil)
end

T['setup()']['ignores keys outside the defaults schema'] = function()
    config.setup({ unknown = true })
    eq(config.unknown, nil)
end

return T
