---@alias OlloumaDevReloadablePlugin "ollouma"|"telescope.nvim"



local M = {}


---@param plugins? OlloumaDevReloadablePlugin[]
function M.reload_plugins(plugins)
    plugins = plugins or { 'ollouma', 'telescope.nvim' }
    local log = require('ollouma.util.log')
    require('ollouma.generate.ui'):close()

    for _, plugin in ipairs(plugins) do
        vim.cmd('Lazy reload ' .. plugin)
        log.info('Reloaded plugin ' .. plugin)
    end

end

return M

