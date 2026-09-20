local M = {}

--- Remove CSS comments from content
--- @param content string CSS content
--- @return string Content without comments
local function remove_css_comments(content)
  -- Remove block comments /* ... */
  -- Use a loop to handle nested/multiple comments
  -- [%s%S] matches any character including newlines
  local result = content
  local prev
  repeat
    prev = result
    result = result:gsub('/%*[%s%S]-%*/', '')
  until result == prev

  return result
end

--- Parse CSS file and extract class names
--- @param css_path string Path to the CSS file
--- @return table|nil Table of class names with metadata, or nil on error
function M.parse_css_classes(css_path)
  -- Check if file exists
  local file = io.open(css_path, 'r')
  if not file then
    return nil
  end

  local content = file:read('*all')
  file:close()

  -- Remove all CSS comments first
  content = remove_css_comments(content)

  local classes = {}

  -- Extract class selectors from CSS
  -- Strategy: Find selector blocks (everything before '{')
  -- Then extract class names from those selectors only

  -- Split content into rules by finding { } blocks
  for selector_block in content:gmatch('([^{}]+){') do
    -- Now we have only the selector part (before the '{')
    -- Extract class names from this selector block
    -- Pattern matches: .classname, .class-name, .class1.class2, etc.

    for class_selector in selector_block:gmatch('%.([%w%-_]+)') do
      -- Validate the class name:
      -- 1. Must not start with a digit (invalid CSS)
      -- 2. Must not be empty
      -- 3. Filter out pseudo-classes and elements (already handled by pattern, but double-check)

      if class_selector and
         #class_selector > 0 and
         not class_selector:match('^%d') and  -- Don't start with digit
         not class_selector:match(':') and
         not class_selector:match('::') then

        -- Store unique class names
        if not classes[class_selector] then
          classes[class_selector] = {
            name = class_selector,
            -- We could extract more info here if needed (description, category, etc.)
          }
        end
      end
    end
  end

  return classes
end

--- Extract category from Bootstrap class name
--- This helps provide better documentation and grouping
--- @param class_name string
--- @return string Category name
function M.get_class_category(class_name)
  -- Spacing utilities
  if class_name:match('^[mp][tblrxy]?%-[0-9]+$') or class_name:match('^[mp][tblrxy]?%-auto$') then
    return 'Spacing'
  end

  -- Font size
  if class_name:match('^fs%-[0-9]+$') then
    return 'Typography'
  end

  -- Text utilities
  if class_name:match('^text%-') then
    return 'Text'
  end

  -- Background utilities
  if class_name:match('^bg%-') then
    return 'Background'
  end

  -- Border utilities
  if class_name:match('^border') then
    return 'Border'
  end

  -- Display utilities
  if class_name:match('^d%-') then
    return 'Display'
  end

  -- Flexbox utilities
  if class_name:match('^flex%-') or class_name:match('^justify%-') or class_name:match('^align%-') then
    return 'Flexbox'
  end

  -- Grid utilities
  if class_name:match('^g%-') or class_name:match('^col%-') or class_name:match('^row%-') then
    return 'Grid'
  end

  -- Width and height
  if class_name:match('^[wh]%-') then
    return 'Sizing'
  end

  -- Position utilities
  if class_name:match('^position%-') or class_name:match('^top%-') or class_name:match('^bottom%-') or class_name:match('^start%-') or class_name:match('^end%-') then
    return 'Position'
  end

  -- Visibility
  if class_name:match('^visible') or class_name:match('^invisible') then
    return 'Visibility'
  end

  return 'Utility'
end

--- Generate documentation for a Bootstrap utility class
--- @param class_name string
--- @return string Documentation in markdown format
function M.get_class_documentation(class_name)
  local category = M.get_class_category(class_name)
  local doc = 'Bootstrap utility class'

  -- Add category information
  doc = doc .. '\n\n**Category:** ' .. category

  -- Add specific descriptions based on patterns
  if class_name:match('^m[tblrxy]?%-') then
    doc = doc .. '\n\n**Type:** Margin utility'
  elseif class_name:match('^p[tblrxy]?%-') then
    doc = doc .. '\n\n**Type:** Padding utility'
  elseif class_name:match('^fs%-[0-9]+$') then
    doc = doc .. '\n\n**Type:** Font size utility'
  elseif class_name:match('^text%-') then
    doc = doc .. '\n\n**Type:** Text utility (color, alignment, decoration, etc.)'
  elseif class_name:match('^bg%-') then
    doc = doc .. '\n\n**Type:** Background color utility'
  elseif class_name:match('^d%-') then
    doc = doc .. '\n\n**Type:** Display utility'
  end

  return doc
end

return M
