local map_options = {
    silent = true,
    desc = 'Describe Unicode codepoints (selected or under the cursor)',
}

vim.keymap.set('n', '<Plug>(unilove-describe)', function()
    local unilove = require 'unilove'
    unilove.describe()
end, map_options)

if vim.fn.mapcheck('ga', 'n') == '' then
    vim.keymap.set('n', 'ga', '<Plug>(unilove-describe)', map_options)
end

-- A Lua callback mapping runs without leaving visual mode, so the selection
-- values are read from `line('v')`, `col('v')` and `mode()` just fine.
vim.keymap.set('x', '<Plug>(unilove-describe)', function()
    local unilove = require 'unilove'
    local buffer = vim.api.nvim_get_current_buf()
    local start = { buffer, vim.fn.line('v'), vim.fn.col('v'), 0 }
    local finish = { buffer, vim.fn.line('.'), vim.fn.col('.'), 0 }
    local text = vim.fn.getregion(start, finish, { type = vim.fn.mode() })
    unilove.describe(table.concat(text, '\n'))
end, map_options)

if vim.fn.mapcheck('ga', 'x') == '' then
    vim.keymap.set('x', 'ga', '<Plug>(unilove-describe)', map_options)
end

vim.api.nvim_create_user_command('Unilove', function(command)
    if command.bang then
        local data = require 'unilove.data'
        local ok, path = pcall(data.update)
        if ok then
            vim.api.nvim_echo({ { 'UnicodeData.txt updated: ' .. path } }, false, {})
        else
            vim.api.nvim_echo({ { path, 'ErrorMsg' } }, true, {})
        end
    else
        local unilove = require 'unilove'
        unilove.describe(command.args)
    end
end, {
    nargs = '?',
    bang = true,
    desc = 'Describe Unicode character under the cursor (or the text passed as '
           .. 'arguments). With `!`, UnicodeData.txt is (re)downloaded.',
})
