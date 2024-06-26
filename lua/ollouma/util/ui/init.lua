-- ---@alias OlloumaHighlightGroup 'OlloumaChatMessageRole'|'OlloumaChatMessageContent'

return {
    -- ---@type table<string, OlloumaHighlightGroup>
    ---@enum OlloumaHighlightGroup
    highlight_groups = {
        chat_role = 'OlloumaChatMessageRole',
        chat_content = 'OlloumaChatMessageContent',
        loading_indicator = 'OlloumaChatLoadingIndicator',
        error_title = 'OlloumaErrorTitle',
        error_details = 'OlloumaErrorDetails',
        -- error_reason = 'OlloumaErrorReason',
    },
    namespace_id = vim.api.nvim_create_namespace('Ollouma'),
    OlloumaSplitUi = require('ollouma.util.ui.split'),
    OlloumaSplitKind = require('ollouma.util.ui.split.split-kind')
}
