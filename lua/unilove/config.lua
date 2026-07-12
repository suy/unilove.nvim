local unilove_config = {
    unicode_data_path = nil,
    format = nil,
    separator = '\t',
    show_octal = false,
    show_name = true,
    show_digraphs = false,
    show_html_entities = false,
}

function unilove_config.setup(options)
    for key, value in pairs(unilove_config) do
        if options[key] ~= nil then
            unilove_config[key] = options[key]
        end
    end
end

return unilove_config
