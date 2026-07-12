local M = {}

local ok, pick = pcall(require, 'mini.pick')
if not ok then
    vim.notify('unilove.pick requires mini.pick to be installed', vim.log.levels.WARN)
    return M
end

local function entry_text(entry)
    local text = vim.fn.nr2char(entry.codepoint)
    local hex = ('U+%04X'):format(entry.codepoint)
    return text .. '  ' .. entry.name .. '  ' .. hex
end

function M.pick()
    local data = require('unilove.data')

    local parsed = data.load()
    local entries = data.entries(parsed)

    local items = {}
    for _, entry in ipairs(entries) do
        items[#items + 1] = {
            codepoint = entry.codepoint,
            text = entry_text(entry),
        }
    end

    pick.start({
        source = {
            name = 'Unicode codepoints',
            items = items,
            choose = function(item)
                local text = vim.fn.nr2char(item.codepoint)
                local target = pick.get_picker_state().windows.target
                vim.api.nvim_win_call(target, function()
                    vim.api.nvim_put({ text }, 'c', true, true)
                end)
            end,
        },
        mappings = {
            copy = {
                char = '<C-y>',
                func = function()
                    local matches = pick.get_picker_matches()
                    if matches.current then
                        vim.fn.setreg('+', vim.fn.nr2char(matches.current.codepoint))
                        pick.stop()
                    end
                end,
            },
        },
    })
end

pick.registry.unilove = M.pick

return M
