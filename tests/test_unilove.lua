local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local unilove = require('unilove')
local config = require('unilove.config')

local fixture_path = vim.fs.joinpath('tests', 'fixtures', 'UnicodeData.txt')

local null = '\0'
local newline = '\n'
local combining_acute = '\u{0301}'
local combining_grave = '\u{0300}'
local accented_a = 'a' .. combining_acute
local grave_a = 'a' .. combining_grave
local a_acute_grave = accented_a .. combining_grave
local thumbs_up = '\u{1F44D}'
local light_skin_tone = '\u{1F3FB}'
local thumbs_up_light_skin = thumbs_up .. light_skin_tone
local woman = '\u{1F469}'
local girl = '\u{1F467}'
local zero_width_joiner = '\u{200D}'
local woman_and_girl = woman .. zero_width_joiner .. girl
local regional_indicator_e = '\u{1F1EA}'
local regional_indicator_u = '\u{1F1FA}'
local eu_flag = regional_indicator_e .. regional_indicator_u

local T = new_set({
    hooks = {
        pre_case = function()
            config.setup()
        end,
    },
})

-- `first_grapheme` is basically `vim.fn.matchstr` in disguise, so strictly
-- speaking, there is no need to test it very thoroughly. However, we test that
-- it does what we expect it to do in quite a few cases, to prevent surprises.
T['first_grapheme()'] = new_set()

T['first_grapheme()']['requires a string'] = function()
    expect.error(function()
        unilove.first_grapheme(1)
    end, 'assertion failed')
end

T['first_grapheme()']['returns an empty string for empty text'] = function()
    eq(unilove.first_grapheme(''), '')
end

T['first_grapheme()']['is able to accept null bytes'] = function()
    eq(unilove.first_grapheme('\0'), '\0')
    eq(unilove.first_grapheme('\0ab'), '\0')
    eq(unilove.first_grapheme('a\0b'), 'a')
    eq(unilove.first_grapheme('ab\0'), 'a')
end

T['first_grapheme()']['works on an ASCII-only string'] = function()
    eq(unilove.first_grapheme('abc'), 'a')
    eq(unilove.first_grapheme('@bc'), '@')
    eq(unilove.first_grapheme('^bc'), '^')
    eq(unilove.first_grapheme('.bc'), '.')
    eq(unilove.first_grapheme(';bc'), ';')
end

T['first_grapheme()']['works on "simple" graphemes above the ASCII range'] = function()
    -- Europe.
    eq(unilove.first_grapheme('ábé'), 'á')
    eq(unilove.first_grapheme('åbé'), 'å')
    eq(unilove.first_grapheme('Æøß'), 'Æ')
    eq(unilove.first_grapheme('Çbé'), 'Ç')
    -- IPA.
    eq(unilove.first_grapheme('əɮ'), 'ə')
    eq(unilove.first_grapheme('ɮə'), 'ɮ')
    -- Asia.
    eq(unilove.first_grapheme('ヵbé'), 'ヵ')
    eq(unilove.first_grapheme('ヌbé'), 'ヌ')
    eq(unilove.first_grapheme('ㄅㄗß'), 'ㄅ')
end

T['first_grapheme()']['keeps combining marks with their base character'] = function()
    eq(unilove.first_grapheme(accented_a .. 'b'), accented_a)
    eq(unilove.first_grapheme(grave_a .. 'b'), grave_a)
    eq(unilove.first_grapheme(a_acute_grave .. 'b'), a_acute_grave)
end

T['first_grapheme()']['keeps emoji modifiers and ZWJ sequences together'] = function()
    eq(unilove.first_grapheme(thumbs_up_light_skin .. 'x'), thumbs_up_light_skin)
    eq(unilove.first_grapheme(woman_and_girl .. 'x'), woman_and_girl)
end

--------------------------------------------------------------------------------

T['codepoint_positions()'] = new_set()

T['codepoint_positions()']['returns the start of each codepoint in valid text'] = function()
    eq(unilove.codepoint_positions('A' .. thumbs_up .. 'a'), { 1, 2, 6 })
    eq(unilove.codepoint_positions('abc'), { 1, 2, 3 })
end

T['codepoint_positions()']['walks embedded null bytes'] = function()
    eq(unilove.codepoint_positions('a\0b'), { 1, 2, 3 })
end

-- Invalid sequences follow `vim.str_utf_pos`: a lead byte interrupted by a
-- non-continuation byte stands alone, and the walk is byte-wise from there;
-- a sequence truncated only by the end of the string consumes its partial run
-- of continuation bytes. This way no byte of the line is ever skipped.
T['codepoint_positions()']['leaves an interrupted lead byte standalone'] = function()
    eq(unilove.codepoint_positions(string.char(0xC3) .. 'A'), { 1, 2 })
    eq(unilove.codepoint_positions(string.char(0xC3) .. 'abc'), { 1, 2, 3, 4 })
    eq(unilove.codepoint_positions(string.char(0xE2, 0x41, 0x42)), { 1, 2, 3 })
    eq(unilove.codepoint_positions(string.char(0xE2, 0x82, 0x41)), { 1, 2, 3 })
    eq(unilove.codepoint_positions(string.char(0xF0, 0x9F, 0x41, 0x42)), { 1, 2, 3, 4 })
end

T['codepoint_positions()']['consumes complete sequences, even overlong or out of range'] = function()
    eq(unilove.codepoint_positions(string.char(0xF5, 0x80, 0x80, 0x80) .. 'a'), { 1, 5 })
    eq(unilove.codepoint_positions(string.char(0xC0, 0x80) .. 'a'), { 1, 3 })
    eq(unilove.codepoint_positions(string.char(0xC3, 0x80, 0x80) .. 'a'), { 1, 3, 4 })
end

T['codepoint_positions()']['consumes sequences truncated only by the end of the string'] = function()
    eq(unilove.codepoint_positions(string.char(0xE2, 0x82)), { 1 })
    eq(unilove.codepoint_positions(string.char(0xF0, 0x80)), { 1 })
end

T['codepoints()'] = new_set()

T['codepoints()']['returns the codepoints in a string'] = function()
    eq(unilove.codepoints('A' .. thumbs_up), { 0x41, 0x1F44D })
end

T['codepoints()']['keeps combining marks and emoji modifiers as separate codepoints'] = function()
    eq(unilove.codepoints(accented_a), { 0x61, 0x301 })
    eq(unilove.codepoints(grave_a), { 0x61, 0x300 })
    eq(unilove.codepoints(thumbs_up_light_skin), { 0x1F44D, 0x1F3FB })
end

T['codepoints()']['keeps multiple combining marks as separate codepoints'] = function()
    eq(unilove.codepoints(a_acute_grave), { 0x61, 0x301, 0x300 })
end

T['codepoints()']['keeps the codepoints in a ZWJ sequence'] = function()
    eq(unilove.codepoints(woman_and_girl), { 0x1F469, 0x200D, 0x1F467 })
end

T['codepoints()']['handles NUL, which Lua string iteration omits'] = function()
    eq(unilove.codepoints(null), { 0 })
end

T['codepoints()']['keeps null bytes inside text'] = function()
    eq(unilove.codepoints('a\0b'), { 0x61, 0x00, 0x62 })
end

T['codepoints()']['reports an invalid lead byte as its own value, losing no characters'] = function()
    eq(unilove.codepoints(string.char(0xC3) .. 'abc'), { 0xC3, 0x61, 0x62, 0x63 })
    eq(unilove.codepoints(string.char(0xE2, 0x82, 0x41)), { 0xE2, 0x82, 0x41 })
end

T['codepoints()']['returns an empty array for an empty string'] = function()
    eq(unilove.codepoints(''), {})
end

T['grapheme_at()'] = new_set()

T['grapheme_at()']['finds ASCII characters using one-based byte columns'] = function()
    eq(unilove.grapheme_at('abc', 1), 'a')
    eq(unilove.grapheme_at('abc', 2), 'b')
    eq(unilove.grapheme_at('abc', 3), 'c')
end

T['grapheme_at()']['returns the complete grapheme at each byte in a combining sequence'] = function()
    local text = accented_a .. 'b'
    for column = 1, #accented_a do
        eq(unilove.grapheme_at(text, column), accented_a)
    end
    eq(unilove.grapheme_at(text, #accented_a + 1), 'b')
end

T['grapheme_at()']['keeps multiple combining marks together at every byte'] = function()
    local text = a_acute_grave .. 'b'
    for column = 1, #a_acute_grave do
        eq(unilove.grapheme_at(text, column), a_acute_grave)
    end
    eq(unilove.grapheme_at(text, #a_acute_grave + 1), 'b')
end

T['grapheme_at()']['returns a multibyte codepoint at all of its byte columns'] = function()
    local text = 'A' .. thumbs_up .. 'B'
    for column = 2, #thumbs_up + 1 do
        eq(unilove.grapheme_at(text, column), thumbs_up)
    end
    eq(unilove.grapheme_at(text, #thumbs_up + 2), 'B')
end

T['grapheme_at()']['keeps an emoji modifier sequence together at every byte'] = function()
    for column = 1, #thumbs_up_light_skin do
        eq(unilove.grapheme_at(thumbs_up_light_skin, column), thumbs_up_light_skin)
    end
end

T['grapheme_at()']['keeps a ZWJ sequence together at every byte'] = function()
    for column = 1, #woman_and_girl do
        eq(unilove.grapheme_at(woman_and_girl, column), woman_and_girl)
    end
end

T['grapheme_at()']['keeps regional indicators together as a flag'] = function()
    for column = 1, #eu_flag do
        eq(unilove.grapheme_at(eu_flag, column), eu_flag)
    end
end

T['grapheme_at()']['uses a newline for empty lines and columns past the line'] = function()
    eq(unilove.grapheme_at('', 1), newline)
    eq(unilove.grapheme_at('a', 2), newline)
    eq(unilove.grapheme_at(thumbs_up, #thumbs_up + 1), newline)
end

T['grapheme_at()']['finds the character after an invalid lead byte'] = function()
    local text = string.char(0xC3) .. 'abc'
    eq(unilove.grapheme_at(text, 1), string.char(0xC3))
    eq(unilove.grapheme_at(text, 2), 'a')
    eq(unilove.grapheme_at(text, 3), 'b')
    eq(unilove.grapheme_at(text, 4), 'c')
end

T['grapheme_at()']['returns the null byte inside a line'] = function()
    eq(unilove.grapheme_at('a\0b', 2), '\0')
end

T['format_one()'] = new_set()

T['format_one()']['formats a printable character and its Unicode name'] = function()
    config.setup({ unicode_data_path = fixture_path })
    eq(unilove.format_one(0x41), 'A\t65\tU+0041 LATIN CAPITAL LETTER A')
end

T['format_one()']['formats control characters readably'] = function()
    config.setup({ show_name = false })
    eq(unilove.format_one(0), 'NUL\t0')
    eq(unilove.format_one(1), '^A\t1')
    eq(unilove.format_one(127), '^?\t127')
end

T['format_one()']['adds an octal representation only below 256'] = function()
    config.setup({ show_name = false, show_octal = true })
    eq(unilove.format_one(0x41), 'A\t65\t\\101')
    eq(unilove.format_one(0x100), 'Ā\t256')
end

T['format_one()']['uses the configured separator'] = function()
    config.setup({ show_name = false, separator = ' | ' })
    eq(unilove.format_one(0x41), 'A | 65')
end

T['format_one()']['adds configured HTML entities'] = function()
    config.setup({ show_name = false, show_html_entities = true })
    eq(unilove.format_one(0x40), '@\t64\t&commat;')
end

T['format()'] = new_set()

T['format()']['returns one line per codepoint'] = function()
    config.setup({ show_name = false })
    eq(unilove.format('AB'), 'A\t65\nB\t66')
end

T['format()']['formats each codepoint in a grapheme independently'] = function()
    config.setup({ show_name = false })
    eq(unilove.format(accented_a), 'a\t97\n' .. combining_acute .. '\t769')
end

T['format()']['formats each codepoint in a multi-combining grapheme independently'] = function()
    config.setup({ show_name = false })
    local expected = 'a\t97\n' .. combining_acute .. '\t769\n' .. combining_grave .. '\t768'
    eq(unilove.format(a_acute_grave), expected)
end

T['format()']['returns an empty string for empty text'] = function()
    eq(unilove.format(''), '')
end

return T
