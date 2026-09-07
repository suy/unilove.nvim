local M = {}

local config = require('unilove.config')

-- Values of the *start* of some important UTF-8 ranges. First goes ASCII, then
-- continuation bytes, then the leading bytes for 2, 3 and 4-byte sequences.
local CONTINUATION = 0x80
local LEADING2 = 0xC0
local LEADING3 = 0xE0
local LEADING4 = 0xF0



--- Calculates the expected codepoint length in bytes when given the first byte
--- of the codepoint. Note that this treats every byte value below the first
--- leading byte value (LEADING2) as 1. However, in other circumstances, a check
--- like this would only admit the ASCII range as size 1, and *reject* the
--- continuation bytes, as those are invalid as first byte. We support them, as
--- we try to be "correct" (not useless) with invalid UTF-8. We don't special
--- case invalid leading bytes like 0xC0 and 0xC1 either.
--- @param byte integer First byte of a sequence.
--- @return integer Length in bytes (1 to 4).
local function expected_length(byte)
    if     byte < LEADING2 then return 1
    elseif byte < LEADING3 then return 2
    elseif byte < LEADING4 then return 3
    else return 4
    end
end

--- Length in bytes of the UTF-8 sequence starting at `start`. Mirrors how
--- `vim.str_utf_pos` treats invalid input, so that no byte is ever skipped:
--- sequences interrupted by a non-continuation byte leave the lead byte
--- standalone (byte-wise), while sequences truncated only by the end of the
--- string consume their partial run of continuation bytes.
--- @param text string
--- @param start integer Byte position of the sequence lead byte (1-indexed).
--- @return integer Length in bytes (1 to 4).
function M.sequence_length(text, start)
    local byte = text:byte(start)
    if byte < CONTINUATION then -- ASCII.
        return 1
    end
    local expected = expected_length(byte)
    local length = 1
    while length < expected do
        local continuation = text:byte(start + length)
        -- End of string: return the partial run counted so far.
        if continuation == nil then
            return length
        end
        -- Interrupted by a non-continuation byte: the lead byte stands alone.
        if continuation < CONTINUATION or continuation >= LEADING2 then
            return 1
        end
        length = length + 1
    end
    return expected
end

--- Returns an iterator over the codepoint positions in `text`. Unlike
--- `vim.str_utf_pos`, it's safe for strings containing null bytes.
--- @param text string
--- @return fun(): integer? Byte position of the next codepoint start, or nil when exhausted.
function M.codepoint_positions(text)
    local position = 1
    return function()
        if position > #text then
            return nil
        end
        local start = position
        position = position + M.sequence_length(text, position)
        return start
    end
end

--- Codepoints (scalar values) of every sequence in `text`, in order. Invalid
--- bytes are reported as their own byte value, losing nothing that follows.
--- @param text string
--- @return integer[] Codepoint values, in order.
function M.codepoints(text)
    local result = {}
    for start in M.codepoint_positions(text) do
        local byte = text:byte(start)
        if byte < CONTINUATION then
            table.insert(result, byte)
        else
            local length = M.sequence_length(text, start)
            local sequence = text:sub(start, start + length - 1)
            table.insert(result, vim.fn.char2nr(sequence))
        end
    end
    return result
end



--- Since `vim.fn.matchstr` doesn't accept anything containing NUL (it gets
--- converted to `Blob` when passed to VimL), we handle them ourselves: a leading
--- NUL is a complete grapheme by itself (control bytes always break clusters),
--- and a later NUL can only sit at or after the end of the first grapheme, so
--- truncating just before it leaves the first grapheme intact for `matchstr`.
--- @param text string
--- @return string The first grapheme cluster; empty string for empty text.
function M.first_grapheme(text)
    assert(type(text) == 'string')
    local null = text:find('\0')
    if null then
        if null == 1 then
            return '\0'
        end
        text = text:sub(1, null - 1)
    end
    return vim.fn.matchstr(text, '.')
end

--- @param line string The buffer line contents.
--- @param column integer Byte column into `line` (1-indexed).
--- @return string The grapheme cluster at the column, or a newline for empty
---   lines and columns past the end.
function M.grapheme_at(line, column)
    -- Empty lines or lines where the cursor is beyond the line length (e.g.
    -- `virtualedit=onemore`).
    if #line == 0 or column > #line then
        return '\n'
    end

    for start in M.codepoint_positions(line) do
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

--- @return string The grapheme under the cursor, or a newline (see `grapheme_at`).
function M.cursor_grapheme()
    local line = vim.api.nvim_get_current_line()
    local column = vim.api.nvim_win_get_cursor(0)[2] + 1
    return M.grapheme_at(line, column)
end



--- @param codepoint integer
--- @return string The "character" for the codepoint, via `nr2char`.
local function codepoint_to_character(codepoint)
    return vim.fn.nr2char(codepoint)
end

-- We need to special case `strtrans` because, due to implementation reasons,
-- it doesn't support null bytes (the same limitation that we have with other
-- functions) and because the editor represents NUL as NL internally (because
-- the NL character is free, as it handles the buffer as an array of lines, so
-- the NL is at the end of the string implicitly).
local function prettify(codepoint)
    if codepoint == 0 then
        return '^@'
    elseif codepoint == 10 then
        return '^J'
    end
    return vim.fn.strtrans(codepoint_to_character(codepoint))
end

local function to_octal(codepoint)
    return ('\\%03o'):format(codepoint)
end

--- @param codepoint integer
--- @return string One line of the `:Unilove` output: fields joined by the
---   configured separator.
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

--- @param text string
--- @return string One line per codepoint, joined by newlines; a single line
---   for a single codepoint.
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

--- @param text? string Text to describe; defaults to the grapheme under the cursor.
function M.describe(text)
    if text == nil or text == '' then
        text = M.cursor_grapheme()
    end
    local format = config.format or M.format
    vim.api.nvim_echo({ { format(text) } }, false, {})
end

return M
