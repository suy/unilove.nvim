local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local data = require('unilove.data')

-- https://www.unicode.org/reports/tr44/#UnicodeData.txt
-- The format is a bit of a mess. The indexes are 0-based in the spec (so
-- in Lua is 1 more), and here are noted as in the spec, not in Lua.
-- (1) name. (10) old Unicode 1.0 name.
local sample = {
    '0000;<control>;Cc;0;BN;;;;;N;NULL;;;;',
    '0009;<control>;Cc;0;S;;;;;N;CHARACTER TABULATION;;;;',
    '0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;',
    '0061;LATIN SMALL LETTER A;Ll;0;L;;;;;N;;;0041;;0041',
    '4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;',
    '9FFF;<CJK Ideograph, Last>;Lo;0;L;;;;;N;;;;;',
    '200B;ZERO WIDTH SPACE;Cf;0;BN;;;;;N;;;;;',
    '1F44D;THUMBS UP SIGN;So;0;ON;;;;;N;;;;;',
}

local T = new_set()

T['parse()'] = new_set()

T['parse()']['returns direct names'] = function()
    local parsed = data.parse(sample)
    eq(parsed.names[0x0041], 'LATIN CAPITAL LETTER A')
    eq(parsed.names[0x0061], 'LATIN SMALL LETTER A')
    eq(parsed.names[0x200B], 'ZERO WIDTH SPACE')
    eq(parsed.names[0x1F44D], 'THUMBS UP SIGN')
end

T['parse()']['uses alias (field 11) for angle-bracket names'] = function()
    local parsed = data.parse(sample)
    eq(parsed.names[0x0000], 'NULL')
    eq(parsed.names[0x0009], 'CHARACTER TABULATION')
end

T['parse()']['parses ranges'] = function()
    local parsed = data.parse(sample)
    eq(#parsed.ranges, 1)
    eq(parsed.ranges[1], { first = 0x4E00, last = 0x9FFF, name = '<CJK Ideograph>' })
end

T['name_for()'] = new_set()

T['name_for()']['looks up direct names'] = function()
    local parsed = data.parse(sample)
    eq(data.name_for(parsed, 0x0041), 'LATIN CAPITAL LETTER A')
    eq(data.name_for(parsed, 0x1F44D), 'THUMBS UP SIGN')
end

T['name_for()']['looks up range names'] = function()
    local parsed = data.parse(sample)
    eq(data.name_for(parsed, 0x4E00), '<CJK Ideograph>')
    eq(data.name_for(parsed, 0x9FFF), '<CJK Ideograph>')
    eq(data.name_for(parsed, 0x6B00), '<CJK Ideograph>')
end

T['name_for()']['returns nil for unknown codepoints'] = function()
    local parsed = data.parse(sample)
    eq(data.name_for(parsed, 0x12345), nil)
end

T['entries()'] = new_set()

T['entries()']['returns named characters sorted by codepoint'] = function()
    local parsed = data.parse(sample)
    local entries = data.entries(parsed)
    eq(#entries, 6)
    eq(entries[1], { codepoint = 0x0000, name = 'NULL' })
    eq(entries[3], { codepoint = 0x0041, name = 'LATIN CAPITAL LETTER A' })
    eq(entries[#entries], { codepoint = 0x1F44D, name = 'THUMBS UP SIGN' })
end

T['entries()']['excludes ranges'] = function()
    local parsed = data.parse(sample)
    local entries = data.entries(parsed)
    for _, entry in ipairs(entries) do
        eq(entry.name:match('^<'), nil)
    end
end

return T
