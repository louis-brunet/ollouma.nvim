return {
    highlight_groups = {
        chat = {
            role = 'OlloumaChatRole',
        },
    },
    namespace_id = vim.api.nvim_create_namespace('Ollouma'),
    OlloumaSplitUi = require('ollouma.util.ui.split'),
    OlloumaSplitKind = require('ollouma.util.ui.split.split-kind')
}
