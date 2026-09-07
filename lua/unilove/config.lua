---@class UniloveConfigOptions
---@field unicode_data_path? string
---@field format? fun(text: string): string
---@field format_one? fun(text: integer): string
---@field separator? string
---@field show_digraphs? boolean
---@field show_html_entities? boolean
---@field show_name? boolean
---@field show_octal? boolean

---@class UniloveConfig: UniloveConfigOptions
---@field setup fun(options?: UniloveConfigOptions)

-- A value to work as a "sentinel" in the defaults table. When a key is set to
-- this `empty` value, it's intended to be `nil`, instead. But a Lua table can't
-- tell the difference between not having an entry or having it set to nil.
local empty = {}

local defaults = {
    unicode_data_path = empty,
    format = empty,
    format_one = empty,
    separator = '\t',
    show_digraphs = false,
    show_html_entities = false,
    show_name = true,
    show_octal = false,
}

-- Defined in two steps to make the LSP server happy. First "forward declare"
-- the table, then create it with the `setup` function that can refer to itself.

---@type UniloveConfig
local unilove_config

unilove_config = {
    ---@param options? UniloveConfigOptions
    setup = function(options)
        options = options or {}
        for key, default in pairs(defaults) do
            local value = options[key]
            if value == nil and default ~= empty then
                value = default
            end
            unilove_config[key] = value
        end
    end,
}

-- Set it to the defaults.
unilove_config.setup()

return unilove_config
