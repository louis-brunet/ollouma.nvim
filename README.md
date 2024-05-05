# ollouma.nvim (WIP)

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
```lua
---@type OlloumaConfig
{
-- TODO: document default config
}
```
### Recommended keymaps

<!-- TODO: recommended keymaps/settings -->

## Usage example

```lua
-- Setup
require('ollouma').setup({
    model = 'llama3',
    api = {
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

-- Hide one or all open chat/generate sessions (close windows)
require('ollouma').hide_session()

-- Reopen any closed windows associated to an open session
require('ollouma').resume_session()

-- Destroy all open sessions (close their buffers/windows and forget them)
require('ollouma').exit_session()
```


