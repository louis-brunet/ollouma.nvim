---@class OlloumaTelescopeEntry
---@field display string
---@field ordinal string
---@field value unknown

-- ---@class OlloumaDevAction
-- ---@field name string
-- ---@field on_select fun(): nil

---@class OlloumaTelescopeModule
local M = {}

-- function M.models(opts)
--     local pickers = require('telescope.pickers')
--     local finders = require('telescope.finders')
--     local conf = require('telescope.config').values
--     local actions = require('telescope.actions')
--     local action_state = require('telescope.actions.state')
--
--     local ollouma = require('ollouma')
--     local models = ollouma.list_models()
--     if not models then
--         vim.notify('Could not get available models', vim.log.levels.INFO)
--         return
--     end
--     ---@type OlloumaModelAction[]
--     local model_actions = {}
--     for model_index, model_name in ipairs(models) do
--         model_actions[model_index] = {
--             model_name = model_name,
--         }
--     end
--
--     opts = require("telescope.themes").get_dropdown(opts)
--
--
--     return pickers.new(
--         opts,
--         {
--             prompt_title = "Available models",
--
--             finder = finders.new_table {
--                 ---@type OlloumaModelAction[]
--                 results = model_actions,
--                 ---@param model_action OlloumaModelAction
--                 entry_maker = function(model_action)
--                     ---@type OlloumaTelescopeEntry
--                     return {
--                         value = model_action,
--                         -- NOTE: use a function to lazy load display name if many
--                         display = model_action.model_name,
--                         ordinal = model_action.model_name,
--                     }
--                 end
--             },
--
--             sorter = conf.generic_sorter(opts),
--
--             attach_mappings = function(prompt_bufnr, map)
--                 actions.select_default:replace(function()
--                     actions.close(prompt_bufnr)
--                     -- error('todo: action')
--                     ---@type OlloumaTelescopeEntry
--                     local selection = action_state.get_selected_entry()
--                     ---@type OlloumaModelAction
--                     local selection_value = selection.value
--
--                     -- TODO: use chosen mode here
--
--                     -- print(vim.inspect(selection))
--                     vim.api.nvim_put({ selection_value.model_name }, "", false, true)
--                 end)
--                 return true
--             end,
--         }
--     ):find()
-- end

-- function M.generate(opts)
--     local pickers = require('telescope.pickers')
--     local finders = require('telescope.finders')
--     local conf = require('telescope.config').values
--     local actions = require "telescope.actions"
--     local action_state = require "telescope.actions.state"
--
--     error('todo')
-- end

-- function M.dev_actions(opts)
--     local pickers = require('telescope.pickers')
--     local finders = require('telescope.finders')
--     local conf = require('telescope.config').values
--     local actions = require "telescope.actions"
--     local action_state = require "telescope.actions.state"
--
--     -- opts = opts or require("telescope.themes").get_dropdown {}
--     opts = require("telescope.themes").get_dropdown(opts)
--     pickers.new(
--         opts,
--         {
--             prompt_title = "Dev Actions",
--
--             finder = finders.new_table {
--                 ---@type OlloumaDevAction[]
--                 results = {
--                     {
--                         name = "Reload all",
--                         on_select = function()
--                             require('ollouma.util.dev').reload_plugins()
--                         end
--                     },
--                     {
--                         name = "Reload ollouma",
--                         on_select = function()
--                             require('ollouma.util.dev').reload_plugins({'ollouma'})
--                         end
--                     },
--                     {
--                         name = "Reload telescope",
--                         on_select = function()
--                             require('ollouma.util.dev').reload_plugins({ "telescope.nvim" })
--                         end
--                     },
--                 },
--                 ---@param action OlloumaDevAction
--                 entry_maker = function(action)
--                     ---@type OlloumaTelescopeEntry
--                     return {
--                         value = action,
--                         -- use a function to lazy load
--                         display = action.name,
--                         ordinal = action.name,
--                     }
--                 end
--             },
--
--             sorter = conf.generic_sorter(opts),
--
--             attach_mappings = function(prompt_bufnr, map)
--                 actions.select_default:replace(function()
--                     actions.close(prompt_bufnr)
--
--                     ---@type OlloumaTelescopeEntry
--                     local selection = action_state.get_selected_entry()
--
--                     ---@type OlloumaDevAction
--                     local dev_action = selection.value
--                     dev_action.on_select()
--                 end)
--                 return true
--             end,
--         }
--     ):find()
-- end

-- function M.generate(opts)
--     local pickers = require('telescope.pickers')
--     local finders = require('telescope.finders')
--     local conf = require('telescope.config').values
--     local actions = require('telescope.actions')
--     local action_state = require('telescope.actions.state')
--
--     opts = opts or {}
--     -- opts = require("telescope.themes").get_dropdown(opts)
--     pickers.new(
--         opts,
--         {
--             prompt_title = "Dev Actions",
--
--             finder = finders.new_table {
--                 ---@type OlloumaDevAction[]
--                 results = {
--                     {
--                         name = "TODO",
--                         on_select = function()
--                             error('TODO')
--                         end
--                     },
--                     -- {
--                     --     name = "Reload ollouma",
--                     --     on_select = function()
--                     --         require('ollouma.util.dev').reload_plugins({'ollouma'})
--                     --     end
--                     -- },
--                 },
--                 ---@param action OlloumaDevAction
--                 entry_maker = function(action)
--                     ---@type OlloumaTelescopeEntry
--                     return {
--                         value = action,
--                         -- use a function to lazy load
--                         display = action.name,
--                         ordinal = action.name,
--                     }
--                 end
--             },
--
--             sorter = conf.generic_sorter(opts),
--
--             attach_mappings = function(prompt_bufnr, map)
--                 actions.select_default:replace(function()
--                     actions.close(prompt_bufnr)
--
--                     ---@type OlloumaTelescopeEntry
--                     local selection = action_state.get_selected_entry()
--
--                     ---@type OlloumaDevAction
--                     local dev_action = selection.value
--                     dev_action.on_select()
--                 end)
--                 return true
--             end,
--         }
--     ):find()
-- end

return M
