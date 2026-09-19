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
      fallback_info = {}, -- Track which packages used fallback: {package_name -> source_package}
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
    return project_cache.tags, project_cache.attributes, project_cache.packages, project_cache.fallback_info
  end

  local all_tags = {}
  local all_attributes = {}
  local loaded_packages = {}
  local fallback_info = {}

  -- Detect and load from all installed Bootstrap Vue packages
  local packages = utils.detect_bootstrap_packages(root)

  if #packages == 0 then
    utils.notify('No Bootstrap Vue packages found in project', vim.log.levels.DEBUG)
  end

  for _, pkg in ipairs(packages) do
    -- Load metadata with automatic fallback support
    local tags, attrs, source_pkg = utils.load_metadata(root, pkg)

    if tags then
      -- Track if fallback was used
      if source_pkg and source_pkg ~= pkg then
        fallback_info[pkg] = source_pkg
      end

      -- Use namespacing to avoid collisions
      for tag_name, tag_info in pairs(tags) do
        local namespaced_key = pkg .. ':' .. tag_name
        if not all_tags[tag_name] then
          -- First occurrence - use it as the default
          all_tags[tag_name] = tag_info
          -- Track all packages using this metadata
          all_tags[tag_name]._used_by = {
            { requested = pkg, source = source_pkg }
          }
        else
          -- Collision detected - add to the used_by list
          table.insert(all_tags[tag_name]._used_by, {
            requested = pkg,
            source = source_pkg
          })
          -- Also store under namespaced key for compatibility
          all_tags[namespaced_key] = tag_info
          all_tags[namespaced_key]._used_by = {
            { requested = pkg, source = source_pkg }
          }
        end
      end
      table.insert(loaded_packages, pkg)
    else
      utils.notify('Failed to load metadata from ' .. pkg, vim.log.levels.WARN)
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
      utils.notify('Failed to load attributes from ' .. pkg, vim.log.levels.WARN)
    end
  end

  -- Update cache
  project_cache.tags = all_tags
  project_cache.attributes = all_attributes
  project_cache.packages = loaded_packages
  project_cache.fallback_info = fallback_info
  project_cache.timestamp = current_time

  return all_tags, all_attributes, loaded_packages, fallback_info
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

  local tags, attributes, packages, fallback_info = load_bootstrap_components()

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

      -- Check _used_by list for fallback usage
      local used_by = tag_info._used_by or {}
      local fallback_warnings = {}

      for _, usage in ipairs(used_by) do
        -- Check if this is a fallback (requested != source)
        if usage.source ~= usage.requested then
          table.insert(fallback_warnings, {
            requested = usage.requested,
            source = usage.source
          })
        end
      end

      for _, attr_name in ipairs(tag_attrs) do
        -- Try to find attribute info
        local attr_key = current_tag .. '/' .. attr_name
        local attr_info = attributes[attr_key] or {}

        local doc_value = attr_info.description or 'Attribute for ' .. current_tag

        -- Add fallback warnings for each package using fallback
        for _, warning in ipairs(fallback_warnings) do
          doc_value = doc_value .. '\n\n⚠️ _Using metadata from `' .. warning.source
            .. '` (fallback for `' .. warning.requested .. '`). Component may not exist or have different props._'
        end

        table.insert(items, {
          label = attr_name,
          kind = require('cmp').lsp.CompletionItemKind.Property,
          documentation = {
            kind = 'markdown',
            value = doc_value,
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
          local doc_value = tag_info.description or 'Bootstrap Vue component'

          -- Check _used_by list for fallback usage
          local used_by = tag_info._used_by or {}
          local fallback_warnings = {}
          local primary_source = nil

          for _, usage in ipairs(used_by) do
            if not primary_source then
              primary_source = usage.requested
            end

            -- Check if this is a fallback (requested != source)
            if usage.source ~= usage.requested then
              table.insert(fallback_warnings, {
                requested = usage.requested,
                source = usage.source
              })
            end
          end

          -- Add source information
          if primary_source then
            doc_value = doc_value .. '\n\n_Source: ' .. primary_source .. '_'
          end

          -- Add fallback warnings for each package using fallback
          for _, warning in ipairs(fallback_warnings) do
            doc_value = doc_value .. '\n\n⚠️ _Using metadata from `' .. warning.source
              .. '` (fallback for `' .. warning.requested .. '`). This component may not exist in `'
              .. warning.requested .. '`._'
          end

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
