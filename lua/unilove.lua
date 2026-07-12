local M = {}

local config = require('unilove.config')

local function codepoint_to_character(codepoint)
    return vim.fn.nr2char(codepoint, true)
end

function M.first_grapheme(text)
    assert(type(text) == 'string')
    return vim.fn.matchstr(text, '.')
end

function M.codepoints(text)
    if text == '\0' then
        return { 0 }
    end

    local result = {}
    for _, start in ipairs(vim.str_utf_pos(text)) do
        result[#result + 1] = vim.fn.char2nr(text:sub(start), true)
    end
    return result
end

function M.grapheme_at(line, column)
    -- Empty lines or lines where the cursor is beyond the line length (e.g.
    -- `virtualedit=onemore`).
    if #line == 0 or column > #line then
        return '\n'
    end

    local codepoint_starts = vim.str_utf_pos(line)
    for _, start in ipairs(codepoint_starts) do
        if start > column then
            break
        end

        local grapheme = M.first_grapheme(line:sub(start))
        if grapheme ~= '' and column < start + #grapheme then
            return grapheme
        end
    end

    return '\n'
end

function M.cursor_grapheme()
    local line = vim.api.nvim_get_current_line()
    local column = vim.api.nvim_win_get_cursor(0)[2] + 1
    return M.grapheme_at(line, column)
end

local function prettify(char, codepoint)
    if codepoint == 0 then
        return 'NUL'
    elseif codepoint < 32 then
        return '^' .. codepoint_to_character(64 + codepoint)
    elseif codepoint == 127 then
        return '^?'
    end
    return tostring(char)
end

local function to_octal(codepoint)
    return ('\\%03o'):format(codepoint)
end

function M.format_one(codepoint)
    local parts = {}
    local char = codepoint_to_character(codepoint)
    table.insert(parts, prettify(char, codepoint))
    table.insert(parts, tostring(codepoint))

    if config.show_octal and codepoint < 256 then
        table.insert(parts, to_octal(codepoint))
    end

    if config.show_name then
        local data = require('unilove.data')
        table.insert(parts, ('U+%04X %s'):format(
            codepoint,
            data.name(codepoint) or '<unknown>'
        ))
    end

    if config.show_digraphs then
        local digraphs = require('unilove.digraphs')
        for _, digraph in ipairs(digraphs.for_codepoint(codepoint)) do
            table.insert(parts, '<C-K>' .. digraph)
        end
    end

    if config.show_html_entities then
        local html_entities = require('unilove.html_entities')
        for _, entity in ipairs(html_entities.for_codepoint(codepoint)) do
            table.insert(parts, entity)
        end
    end

    return table.concat(parts, config.separator)
end

function M.format(text)
    assert(text)
    local codepoints = M.codepoints(text)
    local lines = {}

    for _, codepoint in ipairs(codepoints) do
        table.insert(lines, M.format_one(codepoint))
    end

    if #codepoints == 1 then
        return lines[1]
    end

    return table.concat(lines, '\n')
end

function M.describe(text)
    if text == nil or text == '' then
        text = M.cursor_grapheme()
    end
    local format = config.format or M.format
    vim.api.nvim_echo({ { format(text) } }, false, {})
end

return M
