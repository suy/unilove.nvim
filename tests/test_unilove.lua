local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality
local expect = MiniTest.expect

local unilove = require('unilove')
local config = require('unilove.config')

local fixture_path = vim.fs.joinpath('tests', 'fixtures', 'UnicodeData.txt')

local combining_acute = '\u{0301}'
local combining_grave = '\u{0300}'
local fitzpatrick_one = '\u{1F3FB}'

local a_acute = 'a' .. combining_acute
local a_grave = 'a' .. combining_grave
local a_acute_grave = 'a' .. combining_acute .. combining_grave

local thumbs_up = '\u{1F44D}'
local thumbs_up_light_skin = thumbs_up .. fitzpatrick_one

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

--------------------------------------------------------------------------------

-- The most basic building block of the codepoint walking: how many bytes the
-- sequence starting at `start` occupies. Valid input, plus a taxonomy of the
-- invalid input, which mirrors how `vim.str_utf_pos` treats it.
-- `codepoint_positions()` below walks over these same rules.
T['sequence_length()'] = new_set({
    parametrize = {
        -- ASCII.
        {'Hello', 1, 1},
        {'Hello', 5, 1},

        -- Two byte codepoints, and what follows them.
        {'aliño', 4, 2},
        {'aliño', 6, 1},

        -- Three and four byte codepoints, also not starting at the beginning
        -- of the text.
        {'ἀ', 1, 3},
        {thumbs_up, 1, 4},
        {'日本語', 4, 3},

        -- A lead byte interrupted by a non-continuation byte stands alone.
        {string.char(0xC3) .. 'A', 1, 1},
        {string.char(0xE2, 0x82, 0x41), 1, 1},
        {string.char(0xF0, 0x9F, 0x41, 0x42), 1, 1},
        {string.char(0xF0, 0x9F, 0x8C, 0x41), 1, 1},
        -- Interrupted by the leading byte of another sequence, which may be
        -- complete or incomplete.
        {string.char(0xC3, 0xC3, 0xA5), 1, 1},
        {string.char(0xF0, 0xE2, 0x82, 0xAC), 1, 1},
        {string.char(0xC3, 0xE2, 0x82), 1, 1},

        -- A stranded continuation byte is a sequence of one byte.
        {string.char(0x80), 1, 1},
        {string.char(0xE2, 0x82, 0x41), 2, 1},
        {string.char(0xE2, 0x41, 0x80), 3, 1},
        {string.char(0xC3, 0x80, 0x80) .. 'a', 3, 1},
        -- Same result, different cause: valid text, but the position lands in
        -- the middle of a codepoint. The function only sees the byte at the
        -- position; it cannot tell this 0x97 is a proper continuation of 日.
        {'日本語', 2, 1},

        -- Complete sequences, even when they encode invalid codepoints:
        -- overlong encodings, UTF-16 surrogate halves, out of range values.
        {string.char(0xC0, 0x80), 1, 2},
        {string.char(0xED, 0xA0, 0x80), 1, 3},
        {string.char(0xF5, 0x80, 0x80, 0x80), 1, 4},

        -- A complete sequence is unaffected by the bytes that follow it, and
        -- lead bytes beyond the four byte design (0xF8 and above) are measured
        -- as four byte sequences.
        {string.char(0xC3, 0x80, 0x80) .. 'a', 1, 2},
        {string.char(0xF8, 0x88, 0x80, 0x80), 1, 4},

        -- A sequence truncated only by the end of the string consumes its
        -- partial run of continuation bytes, at every width.
        {string.char(0xC3), 1, 1},
        {string.char(0xE2, 0x82), 1, 2},
        {string.char(0xF0, 0x80), 1, 2},
        {string.char(0xF0, 0x9F, 0x8C), 1, 3},
    },
})

T['sequence_length()']['returns the byte length of the sequence starting at a position'] = function(text, start, expected)
    eq(unilove.sequence_length(text, start), expected)
end

--------------------------------------------------------------------------------

T['codepoint_positions()'] = new_set({
    parametrize = {
        -- Empty text yields nothing.
        {'', {}},

        -- ASCII.
        {'Hello', {1, 2, 3, 4, 5}},
        {'a/b.c', {1, 2, 3, 4, 5}},

        -- Some use of single byte and two byte codepoints.
        {'aliño', {1, 2, 3, 4, 6}},
        {'feliç', {1, 2, 3, 4, 5}},

        -- Pre-composed (NFC) vowels with accents.
        {'àbédö', {1, 3, 4, 6, 7}},
        -- Decomposed (NFD): a plain vowel plus a combining mark.
        {a_acute, {1, 2}},
        {a_acute_grave, {1, 2, 4}},

        -- All multi byte.
        {'ɑάαᶐἀ', {1, 3, 5, 7, 10}},

        -- CJK: hiragana ("kawaii"), katakana ("rāmen"), kanji ("nihongo"),
        -- Mandarin ("Peking duck"), and Cantonese (唔該, "thank you"; 唔 is
        -- essentially unused in Mandarin). All three bytes per codepoint.
        {'かわいい', {1, 4, 7, 10}},
        {'ラーメン', {1, 4, 7, 10}},
        {'日本語', {1, 4, 7}},
        {'北京烤鸭', {1, 4, 7, 10}},
        {'唔該', {1, 4}},

        -- Emoji are just multi byte codepoints to the iterator: modifiers,
        -- ZWJ sequences and flags form graphemes, but that is `grapheme_at`'s
        -- business, not this one's.
        {thumbs_up_light_skin, {1, 5}},
        {woman_and_girl, {1, 5, 8}},
        {eu_flag, {1, 5}},
        {a_acute_grave .. thumbs_up, {1, 2, 4, 6}},
        {'a' .. thumbs_up .. 'b', {1, 2, 6}},

        -- Null bytes are just one more one byte codepoint.
        {'a\0b', {1, 2, 3}},
        {'\0ab', {1, 2, 3}},
        {'ab\0', {1, 2, 3}},

        -- Invalid input follows the same byte level rules as
        -- `sequence_length()` above; what matters here is that, whatever the
        -- corruption, the walk resumes right after it: no byte is skipped.

        -- A lead byte interrupted by a non-continuation byte stands alone.
        {string.char(0xC3) .. 'A', {1, 2}},
        {string.char(0xC3) .. 'abc', {1, 2, 3, 4}},
        {string.char(0xE2, 0x41, 0x42), {1, 2, 3}},
        {string.char(0xF0, 0x41, 0x42), {1, 2, 3}},
        -- Interrupted after one or two continuation bytes.
        {string.char(0xE2, 0x82, 0x41), {1, 2, 3}},
        {string.char(0xF0, 0x9F, 0x41, 0x42), {1, 2, 3, 4}},
        {string.char(0xF0, 0x9F, 0x8C, 0x41), {1, 2, 3, 4}},
        -- Interrupted by the leading byte of another sequence, complete...
        {string.char(0xC3, 0xC3, 0xA5), {1, 2}},
        {string.char(0xF0, 0xE2, 0x82, 0xAC), {1, 2}},
        -- ...or incomplete.
        {string.char(0xC3, 0xE2, 0x82), {1, 2}},

        -- A sequence truncated only by the end of the string consumes its
        -- partial run of continuation bytes.
        {string.char(0xC3), {1}},
        {string.char(0xE2), {1}},
        {string.char(0xE2, 0x82), {1}},
        {string.char(0xF0, 0x80), {1}},
        {string.char(0xF0, 0x9F, 0x8C), {1}},

        -- A stranded continuation byte is a sequence of one byte.
        {string.char(0x80), {1}},
        {string.char(0xE2, 0x41, 0x80), {1, 2, 3}},
        {string.char(0xC3, 0x80, 0x80) .. 'a', {1, 3, 4}},

        -- Complete sequences, even when they encode invalid codepoints
        -- (overlong encodings, surrogates, out of range), are consumed whole.
        {string.char(0xC0, 0x80) .. 'a', {1, 3}},
        {string.char(0xED, 0xA0, 0x80) .. '!', {1, 4}},
        {string.char(0xF5, 0x80, 0x80, 0x80) .. 'a', {1, 5}},
        -- Lead bytes beyond the four byte design are measured as four bytes.
        {string.char(0xF8, 0x88, 0x80, 0x80) .. 'a', {1, 5}},
    },
})

T['codepoint_positions()']['produces the start of each codepoint'] = function(given, expected)
    local result = {}
    for position in unilove.codepoint_positions(given) do
        table.insert(result, position)
    end
    eq(result, expected)
end

-- The property all the rows above exhibit: the walk tiles the text exactly.
-- Every position starts right after the end of the previous sequence, and the
-- last sequence ends at the end of the text. No byte is skipped or revisited.
T['codepoint_positions()']['never skips a byte'] = function(given)
    local covered = 0
    for position in unilove.codepoint_positions(given) do
        eq(position, covered + 1)
        covered = position + unilove.sequence_length(given, position) - 1
    end
    eq(covered, #given)
end

--------------------------------------------------------------------------------

T['codepoints()'] = new_set({
    parametrize = {
        -- Empty text yields no codepoints.
        {'', {}},

        -- Regular text, with a four byte emoji.
        {'A' .. thumbs_up, {0x41, 0x1F44D}},

        -- Combining marks and emoji modifiers are separate codepoints.
        {a_acute, {0x61, 0x301}},
        {a_grave, {0x61, 0x300}},
        {a_acute_grave, {0x61, 0x301, 0x300}},
        {thumbs_up_light_skin, {0x1F44D, 0x1F3FB}},

        -- ZWJ sequences are plain codepoints to this function.
        {woman_and_girl, {0x1F469, 0x200D, 0x1F467}},

        -- Null bytes in every position.
        {'\0', {0}},
        {'a\0b', {0x61, 0x00, 0x62}},
        {'\0ab', {0x00, 0x61, 0x62}},
        {'ab\0', {0x61, 0x62, 0x00}},

        -- Invalid lead bytes are reported as their own values, losing
        -- nothing that follows.
        {string.char(0xC3) .. 'abc', {0xC3, 0x61, 0x62, 0x63}},
        {string.char(0xE2, 0x82, 0x41), {0xE2, 0x82, 0x41}},
    },
})

T['codepoints()']['returns the codepoints of the text'] = function(text, expected)
    eq(unilove.codepoints(text), expected)
end

--------------------------------------------------------------------------------

-- `first_grapheme` is basically `vim.fn.matchstr` in disguise, so strictly
-- speaking, there is no need to test it very thoroughly. However, we test that
-- it does what we expect it to do in quite a few cases to prevent surprises, or
-- in case that we need to replace the implementation for some reason.
T['first_grapheme()'] = new_set({
    parametrize = {
        -- Empty text.
        {'', ''},

        -- Null bytes are accepted in any position.
        {'\0', '\0'},
        {'\0ab', '\0'},
        {'a\0b', 'a'},
        {'ab\0', 'a'},

        -- ASCII letters and punctuation.
        {'abc', 'a'},
        {'@bc', '@'},
        {'^bc', '^'},
        {'.bc', '.'},
        {';bc', ';'},

        -- "Simple" graphemes above the ASCII range. Europe.
        {'ábé', 'á'},
        {'åbé', 'å'},
        {'Æøß', 'Æ'},
        {'Çbé', 'Ç'},
        -- IPA.
        {'əɮ', 'ə'},
        {'ɮə', 'ɮ'},
        -- Asia.
        {'ヵbé', 'ヵ'},
        {'ヌbé', 'ヌ'},
        {'ㄅㄗß', 'ㄅ'},

        -- Combining marks stay with their base.
        {a_acute .. 'b', a_acute},
        {a_grave .. 'b', a_grave},
        {a_acute_grave .. 'b', a_acute_grave},

        -- Emoji modifiers and ZWJ sequences stay together.
        {thumbs_up_light_skin .. 'x', thumbs_up_light_skin},
        {woman_and_girl .. 'x', woman_and_girl},
    },
})

T['first_grapheme()']['returns the first grapheme of the text'] = function(text, expected)
    eq(unilove.first_grapheme(text), expected)
end

--------------------------------------------------------------------------------

-- Rows for `grapheme_at()`: point cases first, and then one row per byte of
-- the multi byte graphemes, to check the "at every byte" property while
-- keeping the failures pinpointing the exact column.
local grapheme_at_rows = {
    -- One-based byte columns.
    {'abc', 1, 'a'},
    {'abc', 2, 'b'},
    {'abc', 3, 'c'},

    -- Empty text and columns past the end yield a newline.
    {'', 1, '\n'},
    {'a', 2, '\n'},
    {thumbs_up, 5, '\n'},

    -- An invalid lead byte stands alone; ASCII resumes byte-wise.
    {string.char(0xC3) .. 'abc', 1, string.char(0xC3)},
    {string.char(0xC3) .. 'abc', 2, 'a'},
    {string.char(0xC3) .. 'abc', 3, 'b'},
    {string.char(0xC3) .. 'abc', 4, 'c'},

    -- The column right after a grapheme starts the next one.
    {a_acute .. 'b', 4, 'b'},

    -- Null byte inside a line.
    {'a\0b', 2, '\0'},
}

-- Every byte column inside these graphemes returns the whole grapheme.
for _, grapheme in ipairs({ a_acute, a_acute_grave, thumbs_up_light_skin, woman_and_girl, eu_flag }) do
    for column = 1, #grapheme do
        table.insert(grapheme_at_rows, { grapheme, column, grapheme })
    end
end

T['grapheme_at()'] = new_set({
    parametrize = grapheme_at_rows,
})

T['grapheme_at()']['returns the grapheme at a one-based byte column'] = function(text, column, expected)
    eq(unilove.grapheme_at(text, column), expected)
end

--------------------------------------------------------------------------------

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

T['format()'] = new_set({
    hooks = {
        pre_case = function()
            config.setup({ show_name = false })
        end,
    },
    parametrize = {
        -- One line per codepoint.
        {'AB', 'A\t65\nB\t66'},

        -- Each codepoint of a grapheme gets its own line.
        {a_acute, 'a\t97\n' .. combining_acute .. '\t769'},
        {a_acute_grave, 'a\t97\n' .. combining_acute .. '\t769\n' .. combining_grave .. '\t768'},

        -- Empty text.
        {'', ''},
    },
})

T['format()']['formats each codepoint on its own line'] = function(text, expected)
    eq(unilove.format(text), expected)
end

return T
