local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local pick = require('unilove.pick')

local T = new_set()

T['entry_text()'] = new_set()

T['entry_text()']['formats an entry for display'] = function()
    local result = pick.entry_text({ codepoint = 0x41, name = 'LATIN CAPITAL LETTER A' })
    eq(result, 'A  LATIN CAPITAL LETTER A  U+0041')
end

T['entry_text()']['formats a codepoint above U+FFFF'] = function()
    local result = pick.entry_text({ codepoint = 0x1F44D, name = 'THUMBS UP SIGN' })
    eq(result, '👍  THUMBS UP SIGN  U+1F44D')
end

T['codepoints_to_text()'] = new_set()

T['codepoints_to_text()']['converts a single item'] = function()
    eq(pick.codepoints_to_text({ { codepoint = 0x41 } }), 'A')
end

T['codepoints_to_text()']['concatenates multiple items'] = function()
    local items = {
        { codepoint = 0x41 },
        { codepoint = 0x42 },
        { codepoint = 0x43 },
    }
    eq(pick.codepoints_to_text(items), 'ABC')
end

T['codepoints_to_text()']['handles multi-byte codepoints'] = function()
    local items = {
        { codepoint = 0x1F44D },
        { codepoint = 0x1F3FB },
    }
    eq(pick.codepoints_to_text(items), '👍🏻')
end

T['codepoints_to_text()']['combines base letter and composing mark'] = function()
    local items = {
        { codepoint = 0x61 },  -- LATIN SMALL LETTER A
        { codepoint = 0x301 }, -- COMBINING ACUTE ACCENT
    }
    eq(pick.codepoints_to_text(items), 'á')
end

T['codepoints_to_text()']['returns empty string for empty input'] = function()
    eq(pick.codepoints_to_text({}), '')
end

T['resolve_items()'] = new_set()

T['resolve_items()']['returns marked items when present'] = function()
    local marked = { { codepoint = 0x41 }, { codepoint = 0x42 } }
    local matches = { marked = marked, current = { codepoint = 0x43 } }
    eq(pick.resolve_items(matches), marked)
end

T['resolve_items()']['falls back to current item when nothing marked'] = function()
    local current = { codepoint = 0x41 }
    local matches = { marked = {}, current = current }
    eq(pick.resolve_items(matches), { current })
end

T['resolve_items()']['returns empty table when nothing available'] = function()
    eq(pick.resolve_items({ marked = {}, current = nil }), {})
    eq(pick.resolve_items({}), {})
end

return T
