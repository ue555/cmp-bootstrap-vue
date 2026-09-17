local utils = require('cmp_bootstrap_vue.utils')

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

--- Get the source name
function source:get_debug_name()
  return 'bootstrap-vue'
end

--- Check if the source is available for the current buffer
function source:is_available()
  -- Only activate in Vue files
  local filetype = vim.bo.filetype
  return filetype == 'vue'
end

--- Get trigger characters
function source:get_trigger_characters()
  return { '<', '-', ' ', '"', "'" }
end

--- Cache for loaded tags and attributes (multi-project support)
local cache = {}

--- Get or create cache for a project root
local function get_cache(root)
  if not cache[root] then
    cache[root] = {
      tags = {},
      attributes = {},
      packages = {},
      timestamp = 0,
    }
  end
  return cache[root]
end

--- Clear cache for a specific root or all roots
function source:clear_cache(root)
  if root then
    cache[root] = nil
  else
    cache = {}
  end
end

--- Load all Bootstrap Vue components from installed packages
local function load_bootstrap_components()
  local root = utils.find_project_root()

  if not root then
    utils.notify('Could not find project root (package.json)', vim.log.levels.WARN)
    return {}, {}, {}
  end

  local project_cache = get_cache(root)

  -- Check if cache is still valid (based on timestamp only)
  local current_time = os.time()
  if project_cache.timestamp > 0 and (current_time - project_cache.timestamp) < 60 then
    return project_cache.tags, project_cache.attributes, project_cache.packages
  end

  local all_tags = {}
  local all_attributes = {}
  local loaded_packages = {}

  -- Detect and load from all installed Bootstrap Vue packages
  local packages = utils.detect_bootstrap_packages(root)

  if #packages == 0 then
    utils.notify('No Bootstrap Vue packages found in project', vim.log.levels.DEBUG)
  end

  for _, pkg in ipairs(packages) do
    local tags = utils.load_vetur_tags(root, pkg)
    local attrs = utils.load_vetur_attributes(root, pkg)

    if tags then
      -- Use namespacing to avoid collisions
      for tag_name, tag_info in pairs(tags) do
        local namespaced_key = pkg .. ':' .. tag_name
        if not all_tags[tag_name] then
          all_tags[tag_name] = tag_info
          all_tags[tag_name]._source_package = pkg
        else
          -- Store collision under namespaced key
          all_tags[namespaced_key] = tag_info
          all_tags[namespaced_key]._source_package = pkg
        end
      end
      table.insert(loaded_packages, pkg)
    else
      utils.notify('Failed to load vetur-tags.json from ' .. pkg, vim.log.levels.WARN)
    end

    if attrs then
      for attr_name, attr_info in pairs(attrs) do
        local namespaced_key = pkg .. ':' .. attr_name
        if not all_attributes[attr_name] then
          all_attributes[attr_name] = attr_info
        else
          -- Store collision under namespaced key
          all_attributes[namespaced_key] = attr_info
        end
      end
    else
      utils.notify('Failed to load vetur-attributes.json from ' .. pkg, vim.log.levels.WARN)
    end
  end

  -- Update cache
  project_cache.tags = all_tags
  project_cache.attributes = all_attributes
  project_cache.packages = loaded_packages
  project_cache.timestamp = current_time

  return all_tags, all_attributes, loaded_packages
end

--- Determine completion context
--- @return string 'tag'|'attribute'|'none'
local function get_completion_context(line, col)
  local before_cursor = line:sub(1, col)

  -- Find last < and > positions
  local last_lt_pos = before_cursor:reverse():find('<')
  local last_gt_pos = before_cursor:reverse():find('>')

  -- Convert reversed positions to actual positions
  if last_lt_pos then
    last_lt_pos = col - last_lt_pos + 1
  end
  if last_gt_pos then
    last_gt_pos = col - last_gt_pos + 1
  end

  -- Outside any tag
  if not last_lt_pos or (last_gt_pos and last_gt_pos > last_lt_pos) then
    return 'none'
  end

  -- Inside a tag (between < and cursor, with no > in between)
  local tag_content = before_cursor:sub(last_lt_pos)

  -- Check if it's a closing tag
  if tag_content:match('^</%s*$') or tag_content:match('^</[%w%-]*$') then
    return 'tag' -- Allow completion for closing tags
  end

  -- Match: <tagname followed by space (attribute context)
  -- Example: "<b-button " or "<b-button variant="
  if tag_content:match('^<[%w%-]+%s+') then
    return 'attribute'
  end

  -- Match: <tagname without space (tag name context)
  -- Example: "<b-" or "<b-button"
  if tag_content:match('^<[%w%-]*$') then
    return 'tag'
  end

  return 'none'
end

--- Extract the current tag name from the line
local function get_current_tag(line, col)
  local before_cursor = line:sub(1, col)

  -- Find last < position
  local last_lt_pos = before_cursor:reverse():find('<')
  if not last_lt_pos then
    return nil
  end

  last_lt_pos = col - last_lt_pos + 1
  local tag_content = before_cursor:sub(last_lt_pos)

  -- Match tag name after <
  -- Example: "<b-button variant=" -> "b-button"
  local tag = tag_content:match('^<([%w%-]+)')
  return tag
end

--- Complete function - provides completion items
function source:complete(params, callback)
  local line = params.context.cursor_line
  local col = params.context.cursor.col

  local tags, attributes, packages = load_bootstrap_components()

  -- If no tags loaded, return empty
  if not next(tags) then
    callback({ items = {}, isIncomplete = false })
    return
  end

  local items = {}
  local context = get_completion_context(line, col)

  if context == 'attribute' then
    -- Provide attribute completion
    local current_tag = get_current_tag(line, col)

    if current_tag and tags[current_tag] then
      local tag_info = tags[current_tag]
      local tag_attrs = tag_info.attributes or {}
      local source_pkg = tag_info._source_package or 'unknown'

      for _, attr_name in ipairs(tag_attrs) do
        -- Try to find attribute info with or without namespace
        local attr_key = current_tag .. '/' .. attr_name
        local namespaced_key = source_pkg .. ':' .. attr_key
        local attr_info = attributes[attr_key] or attributes[namespaced_key] or {}

        table.insert(items, {
          label = attr_name,
          kind = require('cmp').lsp.CompletionItemKind.Property,
          documentation = {
            kind = 'markdown',
            value = attr_info.description or 'Attribute for ' .. current_tag,
          },
          insertText = attr_name .. '=""',
          insertTextFormat = 2, -- Snippet format
        })
      end
    end
  elseif context == 'tag' then
    -- Provide tag completion
    for tag_name, tag_info in pairs(tags) do
      -- Skip namespaced keys (they contain ':')
      if not tag_name:match(':') then
        -- Only show Bootstrap Vue components (starting with b- or Bs or B)
        if tag_name:match('^[bB]%-') or tag_name:match('^Bs') or tag_name:match('^B[A-Z]') then
          local source_pkg = tag_info._source_package or 'unknown'
          local doc_value = tag_info.description or 'Bootstrap Vue component'
          doc_value = doc_value .. '\n\n_Source: ' .. source_pkg .. '_'

          table.insert(items, {
            label = tag_name,
            kind = require('cmp').lsp.CompletionItemKind.Class,
            documentation = {
              kind = 'markdown',
              value = doc_value,
            },
          })
        end
      end
    end
  end

  callback({ items = items, isIncomplete = false })
end

return source
