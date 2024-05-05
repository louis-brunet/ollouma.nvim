-- ---@alias OlloumaHighlightGroup 'OlloumaChatMessageRole'|'OlloumaChatMessageContent'

return {
    -- ---@type table<string, OlloumaHighlightGroup>
    ---@enum OlloumaHighlightGroup
    highlight_groups = {
        chat_role = 'OlloumaChatMessageRole',
        chat_content = 'OlloumaChatMessageContent',
    },
    namespace_id = vim.api.nvim_create_namespace('Ollouma'),
    OlloumaSplitUi = require('ollouma.util.ui.split'),
    OlloumaSplitKind = require('ollouma.util.ui.split.split-kind')
}
