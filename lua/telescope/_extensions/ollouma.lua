return require("telescope").register_extension {
    setup = function(ext_config, config)
        -- access extension config and user config
    end,
    exports = {
        -- -- :Telescope ollouma dev
        -- dev = require('ollouma.telescope').dev_actions,
        --
        -- -- :Telescope ollouma models
        -- models = require('ollouma.telescope').models,
        --
        -- :Telescope ollouma
        -- ollouma = require('ollouma.telescope').select,
    },
}
