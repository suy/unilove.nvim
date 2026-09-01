local M = {}

local config = require('unilove.config')

local function codepoint_to_character(codepoint)
    return vim.fn.nr2char(codepoint, true)
end

function M.first_grapheme(text)
    assert(type(text) == 'string')
    -- vim.fn.matchstr treats NUL bytes as string terminators, so it fails when
    -- a NUL appears after the first character. Truncate at the NUL byte, then
    -- match on the prefix. The text is already the start of where the cursor
    -- is, so we don't need to look past a NUL for the first grapheme.
    local null_pos = text:find('\0')
    if null_pos then
        if null_pos == 1 then
            return '\0'
        end
        text = text:sub(1, null_pos - 1)
    end
    return vim.fn.matchstr(text, '.')
end

-- NB: This is only called on the first byte of a sequence, so continuation
-- bytes (0x80-0xBF) are never passed! That's why the first threshold is 0xC0
-- instead of 0x80, as a quick `man utf8` read would suggest.
local function codepoint_length(byte)
    if     byte < 0xC0 then return 1
        -- continuation bytes
    elseif byte < 0xE0 then return 2
    elseif byte < 0xF0 then return 3
    else return 4
    end
end

-- Length in bytes of the UTF-8 sequence starting at `start`. Mirrors how
-- `vim.str_utf_pos` treats invalid input, so that no byte is ever skipped:
-- sequences interrupted by a non-continuation byte leave the lead byte
-- standalone (byte-wise), while sequences truncated only by the end of the
-- string consume their partial run of continuation bytes.
local function sequence_length(text, start)
    local byte = text:byte(start)
    if byte < 0x80 then
        return 1
    end
    local expected = codepoint_length(byte)
    local length = 1
    while length < expected do
        local following = text:byte(start + length)
        -- Early EOL. Return as many bytes as were counted.
        if following == nil then
            return length
        end
        -- If not a continuation byte, then the start of the `text`, even if it
        -- might have a proper leading byte and a proper continuation byte (or
        -- bytes) after it, it doesn't have all the expeced continuation bytes.
        -- That means it's gonna be treated as if the leading byte is actually
        -- alone, because it's corrupt.
        if following < 0x80 or following > 0xBF then
            return 1
        end
        length = length + 1
    end
    return expected
end

-- Like `vim.str_utf_pos`, but safe for strings containing null bytes, and
-- matching its handling of invalid sequences.
function M.codepoint_positions(text)
    local positions = {}
    local i = 1
    while i <= #text do
        table.insert(positions, i)
        i = i + sequence_length(text, i)
    end
    return positions
end

function M.codepoints(text)
    local result = {}
    for _, start in ipairs(M.codepoint_positions(text)) do
        local byte = text:byte(start)
        if byte < 0x80 then
            table.insert(result, byte)
        else
            local length = sequence_length(text, start)
            table.insert(result, vim.fn.char2nr(text:sub(start, start + length - 1), true))
        end
    end
    return result
end

function M.grapheme_at(line, column)
    -- Empty lines or lines where the cursor is beyond the line length (e.g.
    -- `virtualedit=onemore`).
    if #line == 0 or column > #line then
        return '\n'
    end

    -- this is inefficient, as it goes through all the line, when we really
    -- don't need to go that far. A way to early return, or a way to iterate
    -- through the line step by step, only as needed, would be nice. This would
    -- perhaps be make the API quite complicated, though. But it would be cool.
    local codepoint_starts = M.codepoint_positions(line)
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

local function prettify(codepoint)
    if codepoint == 0 then
        return 'NUL' -- ?? So short??
    end
    return vim.fn.strtrans(codepoint_to_character(codepoint))
end

local function to_octal(codepoint)
    return ('\\%03o'):format(codepoint)
end

function M.format_one(codepoint)
    local parts = {}
    table.insert(parts, prettify(codepoint))
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
