local function find_files()
    local files = {}
    for _, f in ipairs(vim.fn.globpath('tests', 'test_*.lua', false, true)) do
        if not f:match('tests/mini%.nvim/') then
            table.insert(files, f)
        end
    end
    return files
end

MiniTest.run({
    collect = { find_files = find_files },
})
