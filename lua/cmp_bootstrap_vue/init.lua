local M = {}

local utils = require('cmp_bootstrap_vue.utils')

--- Setup function for user configuration
--- @param opts table|nil Configuration options
---   - vetur_tags_path: string - Relative path to vetur-tags.json (default: 'dist/vetur-tags.json')
---   - vetur_attributes_path: string - Relative path to vetur-attributes.json (default: 'dist/vetur-attributes.json')
---   - supported_packages: table - List of supported package names (default: {'bootstrap-vue', 'bootstrap-vue-next'})
---   - notification_level: number - Minimum notification level (default: vim.log.levels.WARN)
function M.setup(opts)
  opts = opts or {}
  utils.set_config(opts)
end

--- Clear cache for current project, specific project, or all projects
--- @param target string|nil Project root path, "all" to clear all, or nil for current project
function M.clear_cache(target)
  local source = require('cmp_bootstrap_vue.source')
  local instance = source.new()

  if target == 'all' then
    -- Clear all caches
    instance:clear_cache(nil)
    utils.notify('All caches cleared', vim.log.levels.INFO)
  elseif target then
    -- Clear specific project
    instance:clear_cache(target)
    utils.notify('Cache cleared for: ' .. target, vim.log.levels.INFO)
  else
    -- Clear current project (default behavior)
    local root = utils.find_project_root()
    if root then
      instance:clear_cache(root)
      utils.notify('Cache cleared for current project: ' .. root, vim.log.levels.INFO)
    else
      utils.notify('Could not find project root', vim.log.levels.WARN)
    end
  end
end

--- Clear all project caches
function M.clear_all_caches()
  M.clear_cache('all')
end

--- Get current configuration
function M.get_config()
  return utils.get_config()
end

--- Manually trigger cache reload for current project
function M.reload()
  local root = utils.find_project_root()
  if root then
    local source = require('cmp_bootstrap_vue.source')
    local instance = source.new()
    instance:clear_cache(root)
    utils.notify('Cache reloaded for: ' .. root, vim.log.levels.INFO)
  else
    utils.notify('Could not find project root', vim.log.levels.WARN)
  end
end

return M
