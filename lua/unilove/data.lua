local M = {}

local remote = 'https://unicode.org/Public/UNIDATA/UnicodeData.txt'
local packaged = '/usr/share/unicode/UnicodeData.txt'

local cache = {}

-- Wrap an array of lines into an iterator, so it's equivalent to `io.lines`.
local function wrap_source(source)
    if type(source) == 'table' then
        local current = 0
        return function()
            current = current + 1
            return current <= #source and source[current] or nil
        end
    elseif type(source) == 'function' then
        return source -- We assume it's a correct iterator function.
    else
        error('parse: source must be an array of strings or an iterator function')
    end
end

--- Parse UnicodeData.txt lines into a lookup table.
---
--- See: https://www.unicode.org/reports/tr44/#UnicodeData.txt
--- The format is a bit messy, so we have to a bit of extra work.
--- The fields are: 0=codepoint, 1=name, 11=legacy Unicode 1.0 name.
--- We use the legacy name for entries whose name is `<abc>`, like `<control>`,
--- which is not as descriptive to us as the legacy name.
---
--- @param source table|function Array of strings (e.g. for tests) or iterator (e.g. io.lines)
--- @return table { names = {[codepoint] = name}, ranges = {{first, last, name}} }
function M.parse(source)
    local result = { names = {}, ranges = {} }
    local pending = {}

    for line in wrap_source(source) do
        local fields = vim.split(line, ';', { plain = true })
        local codepoint = fields[1]
        local name = fields[2]

        local range_first = name:match('^<(.+), First>$')
        local range_last = name:match('^<(.+), Last>$')

        if range_first then
            pending[range_first] = tonumber(codepoint, 16)
        elseif range_last then
            local first = pending[range_last]
            if first then
                table.insert(result.ranges, {
                    first = first,
                    last = tonumber(codepoint, 16),
                    name = '<' .. range_last .. '>',
                })
            end
        else
            -- Control characters are named between brackets as "control",
            -- and their more usual name is the legacy Unicode 1.0 name.
            if name:match('^<') and fields[11] and fields[11] ~= '' then
                name = fields[11]
            end
            result.names[tonumber(codepoint, 16)] = name
        end
    end

    return result
end

--- Look up the name of a codepoint in a parsed table.
--- @param parsed table Result from M.parse()
--- @param codepoint integer
--- @return string|nil
function M.name_for(parsed, codepoint)
    if parsed.names[codepoint] then
        return parsed.names[codepoint]
    end

    for _, range in ipairs(parsed.ranges) do
        if codepoint >= range.first and codepoint <= range.last then
            return range.name
        end
    end

    return nil
end

--- Flatten parsed names into a searchable array, sorted by codepoint.
--- @param parsed table Result from M.parse()
--- @return table Array of { codepoint = integer, name = string }
function M.entries(parsed)
    local result = {}
    for codepoint, name in pairs(parsed.names) do
        table.insert(result, {
            codepoint = codepoint,
            name = name,
        })
    end
    table.sort(result, function(a, b)
        return a.codepoint < b.codepoint
    end)
    return result
end


-- Code below this line starts to use the disk, and being harder to unit test.

local function readable(path)
    return path ~= nil and path ~= '' and vim.fn.filereadable(path) == 1
end

local function user_path()
    return vim.fs.joinpath(vim.fn.stdpath('data'), 'unicode', 'UnicodeData.txt')
end

function M.decide_path(custom)
    if readable(custom) then
        return custom
    elseif readable(packaged) then
        return packaged
    elseif readable(user_path()) then
        return user_path()
    end
end

--- Load and cache parsed UnicodeData.
--- @return table Result from M.parse()
function M.load()
    local config = require('unilove.config')
    local path = M.decide_path(config.unicode_data_path)
    if not path then
        error('UnicodeData.txt not found. Run :Unilove! to download it.')
    end

    if not cache[path] then
        cache[path] = M.parse(io.lines(path))
    end

    return cache[path]
end

function M.name(codepoint)
    return M.name_for(M.load(), codepoint)
end

local function executable(name)
    return vim.fn.executable(name) == 1
end

local function run(argv)
    local result = vim.system(argv, { text = true }):wait()
    if result.code == 0 then
        return true
    end
    return false, result.stderr ~= '' and result.stderr or result.stdout
end

function M.update()
    local target = user_path()
    local dir = vim.fs.dirname(target)
    vim.fn.mkdir(dir, 'p')

    local tmp = target .. '.tmp'
    local ok, message

    if executable('curl') then
        ok, message = run({ 'curl', '-fL', '--create-dirs', '-o', tmp, remote })
    elseif executable('wget') then
        ok, message = run({ 'wget', '-O', tmp, remote })
    else
        error('UnicodeData.txt update requires curl or wget.')
    end

    if not ok then
        vim.fn.delete(tmp)
        error('UnicodeData.txt update failed: ' .. (message or 'unknown error'))
    end

    vim.fn.rename(tmp, target)
    cache = {}
    return target
end

return M
