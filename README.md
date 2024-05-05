# ollouma.nvim (WIP)

Ollama client integration for Neovim.

## Dependencies

### System

- `curl`

## Installation

- with lazy.nvim
    ```lua
    ---@type LazySpec
    {
        'louis-brunet/ollouma.nvim'

        dependencies = {},

        ---@type OlloumaPartialConfig
        opts = {}, -- see configuration options below

        ---@param opts OlloumaPartialConfig
        -- config = function(_, opts)
        --     local ollouma = require('ollouma')
        --
        --     ollouma.setup(opts)
        -- end
    }
    ```

## Setup, configuration options

### Default configuration
See `default_config()` in [lua/ollouma/config/init.lua](./lua/ollouma/config/init.lua).

```lua
---@type OlloumaConfig
{
-- TODO: document default config
}
```
### Recommended keymaps
 
Here are some keymaps you might find useful for common actions.
```lua
-- TODO: this API should be more easily accessible in lua
vim.keymap.set('n', "<leader>oo", ':Ollouma select_action<CR>', { desc = "[o]llouma select action" })
vim.keymap.set('n', "<leader>o",  ':Ollouma select_action<CR>', { desc = "[o]llouma", mode = 'x' })

vim.keymap.set('n', "<leader>oh", function() require('ollouma').hide_session() end, { desc = "[o]llouma: [h]ide session" })
vim.keymap.set('n', "<leader>or", function() require('ollouma').resume_session() end,{ desc = "[o]llouma: [r]esume session" })
vim.keymap.set('n', "<leader>oe", function() require('ollouma').exit_session() end, { desc = "[o]llouma: [e]xit session" })
```

## Usage examples

### Opening a chat interface
```lua
-- Setup
require('ollouma').setup({
    model = 'llama3',
    api = {
        -- this is the default value, but can point to any ollama-compatible
        -- server!
        chat_url = "127.0.0.1:11434/api/chat",
    },
})

-- Open chat prompt buffer in a new split
require('ollouma.chat.ui').start_chat_ui({
    system_prompt = '...',
})

-- ... write prompt
-- ... send prompt with :OlloumaSend
-- ... edit the existing messages in the output buffer
-- ... save the output buffer to change chat history!
```

### Session management
```lua
-- Hide one or all open chat/generate sessions (close windows)
require('ollouma').hide_session()

-- Reopen any closed windows associated to an open session
require('ollouma').resume_session()

-- Destroy all open sessions (close their buffers/windows and forget them)
require('ollouma').exit_session()
```

### Select model action
- `:Ollouma select_action`: choose which of the configured model actions to run. Works in visual mode. Detects when it is being run in visual mode to conditionally show some actions that require a visual selection (e.g. "Review code").
- You can also call `require('ollouma').select_model_action(model, model_action_opts)` from Lua, but for now you have to compute its parameters manually.

### Select model
`:Ollouma select_model`: same as `:Ollouma select_action`, but first query the server for its list of available models. Select one of these, then select a model action to run.

