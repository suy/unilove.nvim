local M = {}

local ok, pick = pcall(require, 'mini.pick')
if not ok then
    vim.notify('unilove.pick requires mini.pick to be installed', vim.log.levels.WARN)
    return M
end

--- @param entry table { codepoint = number, name = string }
--- @return string
function M.entry_text(entry)
    local text = vim.fn.nr2char(entry.codepoint)
    local hex = ('U+%04X'):format(entry.codepoint)
    return text .. '  ' .. entry.name .. '  ' .. hex
end

--- @param items table Array of { codepoint = number }
--- @return string
function M.codepoints_to_text(items)
    local text = {}
    for _, item in ipairs(items) do
        table.insert(text, vim.fn.nr2char(item.codepoint))
    end
    return table.concat(text)
end

--- @param matches table Result of MiniPick.get_picker_matches()
--- @return table Array of items to act on (may be empty)
function M.resolve_items(matches)
    local marked = matches.marked or {}
    if #marked > 0 then
        return marked
    elseif matches.current then
        return { matches.current }
    else
        return {}
    end
end

function M.pick()
    local data = require('unilove.data')

    local parsed = data.load()
    local entries = data.entries(parsed)

    local items = {}
    for _, entry in ipairs(entries) do
        table.insert(items, {
            codepoint = entry.codepoint,
            text = M.entry_text(entry),
        })
    end

    local function insert_items(selected)
        local target = pick.get_picker_state().windows.target
        local text = M.codepoints_to_text(selected)
        vim.api.nvim_win_call(target, function()
            vim.api.nvim_put({ text }, 'c', true, true)
        end)
    end

    pick.start({
        source = {
            name = 'Unicode codepoints',
            items = items,
            choose = function(item)
                insert_items({ item })
            end,
            choose_marked = insert_items,
        },
        mappings = {
            copy = {
                char = '<C-y>',
                func = function()
                    local matches = pick.get_picker_matches() or {}
                    local resolved = M.resolve_items(matches)
                    if #resolved > 0 then
                        vim.fn.setreg('+', M.codepoints_to_text(resolved))
                        pick.stop()
                    end
                end,
            },
        },
    })
end

pick.registry.unilove = M.pick

return M
