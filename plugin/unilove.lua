local map_options = {
    silent = true,
    desc = 'Describe Unicode character under cursor',
}

vim.keymap.set('n', '<Plug>(unilove-describe)', function()
    local unilove = require 'unilove'
    unilove.describe()
end, map_options)

if vim.fn.mapcheck('ga', 'n') == '' then
    vim.keymap.set('n', 'ga', '<Plug>(unilove-describe)', map_options)
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
