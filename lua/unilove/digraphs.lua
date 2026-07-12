local M = {}

local cache

local function build()
    local out = vim.api.nvim_exec2('silent digraphs', { output = true }).output
    local result = {}

    for _, line in ipairs(vim.split(out, '\n', { plain = true, trimempty = true })) do
        for _, entry in ipairs(vim.fn.split(line, [[ \d\+\zs\s*]])) do
            local nr = vim.fn.matchstr(entry, [[\d\+$]])
            if nr == '10' and vim.tbl_count(result) <= 1 then
                nr = '0'
            end
            if nr ~= '' then
                local digraph = vim.fn.matchstr(entry, '^..')
                local key = tonumber(nr)
                result[key] = result[key] or {}
                table.insert(result[key], digraph)
            end
        end
    end

    return result
end

function M.for_codepoint(nr)
    if not cache then
        cache = build()
    end
    return cache[nr] or {}
end

function M.reset()
    cache = nil
end

return M
