local M = {}

-- Default configuration
local config = {
  vetur_tags_path = 'dist/vetur-tags.json',
  vetur_attributes_path = 'dist/vetur-attributes.json',
  supported_packages = {
    'bootstrap-vue',
    'bootstrap-vue-next',
  },
  -- Fallback packages for when metadata is not found
  -- e.g., bootstrap-vue-next doesn't provide Vetur/web-types, so use bootstrap-vue's metadata
  fallback_packages = {
    ['bootstrap-vue-next'] = 'bootstrap-vue',
  },
  notification_level = vim.log.levels.WARN,
}

--- Set configuration
function M.set_config(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})
end

--- Get current configuration
function M.get_config()
  return config
end

--- Send notification to user
--- @param message string The notification message
--- @param level number The log level (vim.log.levels)
function M.notify(message, level)
  level = level or vim.log.levels.INFO
  -- Only notify if level is at or above configured threshold
  if level >= config.notification_level then
    vim.notify('[cmp-bootstrap-vue] ' .. message, level)
  end
end

--- Find the project root by searching for package.json
--- @return string|nil The project root path or nil if not found
function M.find_project_root()
  local current_file = vim.fn.expand('%:p')
  local current_dir = vim.fn.fnamemodify(current_file, ':h')

  -- Search upwards for package.json
  local root = vim.fn.findfile('package.json', current_dir .. ';')
  if root ~= '' then
    return vim.fn.fnamemodify(root, ':h')
  end

  -- Fallback to current working directory
  local cwd_package = vim.fn.getcwd() .. '/package.json'
  if vim.fn.filereadable(cwd_package) == 1 then
    return vim.fn.getcwd()
  end

  return nil
end

--- Read and parse a JSON file
--- @param filepath string The path to the JSON file
--- @return table|nil The parsed JSON data or nil if failed
function M.read_json_file(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    M.notify('File not readable: ' .. filepath, vim.log.levels.DEBUG)
    return nil
  end

  local file = io.open(filepath, 'r')
  if not file then
    M.notify('Failed to open file: ' .. filepath, vim.log.levels.DEBUG)
    return nil
  end

  local content = file:read('*all')
  file:close()

  if not content or content == '' then
    M.notify('Empty file: ' .. filepath, vim.log.levels.DEBUG)
    return nil
  end

  local ok, result = pcall(vim.fn.json_decode, content)
  if ok then
    return result
  else
    M.notify('Failed to parse JSON: ' .. filepath .. ' - ' .. tostring(result), vim.log.levels.ERROR)
    return nil
  end
end

--- Check if a package is installed in the project
--- @param root string The project root directory
--- @param package_name string The package name to check
--- @return boolean True if the package is installed
function M.is_package_installed(root, package_name)
  local package_json = M.read_json_file(root .. '/package.json')
  if not package_json then
    return false
  end

  local dependencies = package_json.dependencies or {}
  local dev_dependencies = package_json.devDependencies or {}

  return dependencies[package_name] ~= nil or dev_dependencies[package_name] ~= nil
end

--- Build vetur file path with fallback options
--- @param root string The project root directory
--- @param package_name string The package name
--- @param file_type string 'tags' or 'attributes'
--- @return string|nil The file path or nil if not found
local function find_vetur_file(root, package_name, file_type)
  local base_path = root .. '/node_modules/' .. package_name

  -- Determine which config path to use
  local relative_path
  if file_type == 'tags' then
    relative_path = config.vetur_tags_path
  else
    relative_path = config.vetur_attributes_path
  end

  local primary_path = base_path .. '/' .. relative_path

  -- Try primary path
  if vim.fn.filereadable(primary_path) == 1 then
    return primary_path
  end

  -- Fallback: try common alternative locations
  local fallback_paths = {
    base_path .. '/dist/vetur-' .. file_type .. '.json',
    base_path .. '/lib/vetur-' .. file_type .. '.json',
    base_path .. '/vetur-' .. file_type .. '.json',
  }

  for _, path in ipairs(fallback_paths) do
    if vim.fn.filereadable(path) == 1 then
      M.notify('Using fallback path: ' .. path, vim.log.levels.DEBUG)
      return path
    end
  end

  return nil
end

--- Load vetur-tags.json from a package
--- @param root string The project root directory
--- @param package_name string The package name
--- @return table|nil The parsed vetur-tags.json or nil if not found
function M.load_vetur_tags(root, package_name)
  local tags_path = find_vetur_file(root, package_name, 'tags')
  if not tags_path then
    M.notify('vetur-tags.json not found for ' .. package_name, vim.log.levels.DEBUG)
    return nil
  end
  return M.read_json_file(tags_path)
end

--- Load vetur-attributes.json from a package
--- @param root string The project root directory
--- @param package_name string The package name
--- @return table|nil The parsed vetur-attributes.json or nil if not found
function M.load_vetur_attributes(root, package_name)
  local attrs_path = find_vetur_file(root, package_name, 'attributes')
  if not attrs_path then
    M.notify('vetur-attributes.json not found for ' .. package_name, vim.log.levels.DEBUG)
    return nil
  end
  return M.read_json_file(attrs_path)
end

--- Load and convert web-types.json to Vetur format
--- @param root string The project root directory
--- @param package_name string The package name
--- @return table|nil, table|nil The parsed tags and attributes or nil if not found
function M.load_web_types(root, package_name)
  local base_path = root .. '/node_modules/' .. package_name

  -- Try different locations for web-types.json
  local web_types_paths = {
    base_path .. '/dist/web-types.json',
    base_path .. '/web-types.json',
  }

  local web_types = nil
  local found_path = nil

  for _, path in ipairs(web_types_paths) do
    if vim.fn.filereadable(path) == 1 then
      web_types = M.read_json_file(path)
      if web_types then
        found_path = path
        break
      end
    end
  end

  if not web_types then
    M.notify('web-types.json not found for ' .. package_name, vim.log.levels.DEBUG)
    return nil, nil
  end

  M.notify('Using web-types.json from: ' .. found_path, vim.log.levels.DEBUG)

  -- Convert web-types.json to Vetur format
  local tags = {}
  local attributes = {}

  -- Extract components from contributions.html.vue-components
  local components = {}
  if web_types.contributions and web_types.contributions.html then
    components = web_types.contributions.html['vue-components'] or {}
  end

  for _, component in ipairs(components) do
    local tag_name = component.name
    if tag_name then
      -- Build attributes list
      local attr_names = {}
      local props = component.props or {}

      for _, prop in ipairs(props) do
        local prop_name = prop.name
        if prop_name then
          table.insert(attr_names, prop_name)

          -- Store attribute info
          local attr_key = tag_name .. '/' .. prop_name
          attributes[attr_key] = {
            description = prop.description or '',
            type = prop.type or 'any',
            default = prop.default,
          }
        end
      end

      -- Store tag info
      tags[tag_name] = {
        description = component.description or '',
        attributes = attr_names,
      }
    end
  end

  if next(tags) then
    M.notify('Loaded ' .. vim.tbl_count(tags) .. ' components from web-types.json (' .. package_name .. ')', vim.log.levels.DEBUG)
    return tags, attributes
  else
    M.notify('No components found in web-types.json (' .. package_name .. ')', vim.log.levels.WARN)
    return nil, nil
  end
end

--- Load metadata with fallback support
--- Tries multiple formats and fallback packages
--- @param root string The project root directory
--- @param package_name string The package name
--- @return table|nil, table|nil, string|nil The parsed tags, attributes, and source package name or nil if not found
function M.load_metadata(root, package_name)
  -- Try Vetur format first
  local tags = M.load_vetur_tags(root, package_name)
  local attrs = M.load_vetur_attributes(root, package_name)

  -- Try web-types.json if Vetur not found
  if not tags or not attrs then
    M.notify('Vetur files not found for ' .. package_name .. ', trying web-types.json', vim.log.levels.DEBUG)
    local web_tags, web_attrs = M.load_web_types(root, package_name)
    if web_tags then
      tags = tags or web_tags
      attrs = attrs or web_attrs
    end
  end

  -- Return if metadata found from the original package
  if tags and attrs then
    return tags, attrs, package_name
  end

  -- Try fallback package if still not found
  if config.fallback_packages[package_name] then
    local fallback_pkg = config.fallback_packages[package_name]
    M.notify(
      'Metadata not found for ' .. package_name .. ', trying fallback package: ' .. fallback_pkg,
      vim.log.levels.INFO
    )

    -- Check if fallback package is installed
    if M.is_package_installed(root, fallback_pkg) then
      -- Try Vetur format from fallback
      local fb_tags = M.load_vetur_tags(root, fallback_pkg)
      local fb_attrs = M.load_vetur_attributes(root, fallback_pkg)

      -- Try web-types from fallback if Vetur not found
      if not fb_tags or not fb_attrs then
        local fb_web_tags, fb_web_attrs = M.load_web_types(root, fallback_pkg)
        if fb_web_tags then
          fb_tags = fb_tags or fb_web_tags
          fb_attrs = fb_attrs or fb_web_attrs
        end
      end

      if fb_tags then
        M.notify('Using metadata from fallback package: ' .. fallback_pkg, vim.log.levels.INFO)
        return fb_tags, fb_attrs, fallback_pkg
      end
    else
      M.notify(
        'Fallback package ' .. fallback_pkg .. ' is not installed. '
        .. 'Install it to enable completion for ' .. package_name,
        vim.log.levels.WARN
      )
    end
  end

  return nil, nil, nil
end

--- Detect which Bootstrap Vue packages are installed
--- @param root string The project root directory
--- @return table A list of installed Bootstrap Vue package names
function M.detect_bootstrap_packages(root)
  local packages = {}

  for _, pkg in ipairs(config.supported_packages) do
    if M.is_package_installed(root, pkg) then
      table.insert(packages, pkg)
    end
  end

  return packages
end

return M
