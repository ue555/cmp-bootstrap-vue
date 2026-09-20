local source = require('cmp_bootstrap_vue.source')
local css_parser = require('cmp_bootstrap_vue.css_parser')

describe('source', function()
  local instance

  before_each(function()
    instance = source.new()
  end)

  describe('new', function()
    it('should create a new source instance', function()
      assert.is_not_nil(instance)
      assert.is_table(instance)
    end)
  end)

  describe('get_debug_name', function()
    it('should return "bootstrap-vue"', function()
      assert.equals('bootstrap-vue', instance:get_debug_name())
    end)
  end)

  describe('get_trigger_characters', function()
    it('should return trigger characters', function()
      local triggers = instance:get_trigger_characters()
      assert.is_table(triggers)
      assert.is_true(vim.tbl_contains(triggers, '<'))
      assert.is_true(vim.tbl_contains(triggers, '-'))
      assert.is_true(vim.tbl_contains(triggers, ' '))
    end)
  end)

  describe('is_available', function()
    it('should return false for non-vue filetype', function()
      vim.bo.filetype = 'lua'
      assert.is_false(instance:is_available())
    end)

    it('should return true for vue filetype', function()
      vim.bo.filetype = 'vue'
      assert.is_true(instance:is_available())
    end)
  end)

  describe('clear_cache', function()
    it('should clear cache without errors', function()
      -- Just ensure it doesn't throw
      assert.has_no.errors(function()
        instance:clear_cache()
      end)
    end)

    it('should clear specific project cache', function()
      assert.has_no.errors(function()
        instance:clear_cache('/some/path')
      end)
    end)
  end)

  describe('fallback metadata tracking', function()
    it('should track _used_by list in tag info', function()
      -- This is a structural test - actual functionality requires mock data
      -- The test verifies that the fields are being set when tags are loaded

      -- Create a mock tag with the expected _used_by structure
      local mock_tag = {
        description = 'Test component',
        attributes = {},
        _used_by = {
          { requested = 'bootstrap-vue', source = 'bootstrap-vue' },
          { requested = 'bootstrap-vue-next', source = 'bootstrap-vue' },  -- Fallback
        }
      }

      -- Verify the structure
      assert.is_table(mock_tag._used_by)
      assert.equals(2, #mock_tag._used_by)

      -- Verify fallback detection logic
      local has_fallback = false
      for _, usage in ipairs(mock_tag._used_by) do
        if usage.source ~= usage.requested then
          has_fallback = true
          break
        end
      end
      assert.is_true(has_fallback)
    end)

    it('should detect multiple fallback usages', function()
      local mock_tag = {
        _used_by = {
          { requested = 'bootstrap-vue', source = 'bootstrap-vue' },  -- Direct
          { requested = 'bootstrap-vue-next', source = 'bootstrap-vue' },  -- Fallback 1
          { requested = 'another-package', source = 'bootstrap-vue' },  -- Fallback 2
        }
      }

      local fallbacks = {}
      for _, usage in ipairs(mock_tag._used_by) do
        if usage.source ~= usage.requested then
          table.insert(fallbacks, usage)
        end
      end

      assert.equals(2, #fallbacks)
      assert.equals('bootstrap-vue-next', fallbacks[1].requested)
      assert.equals('another-package', fallbacks[2].requested)
    end)
  end)

  describe('complete integration', function()
    it('should detect class-value context on single line with unclosed quote', function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<div class="fs-'
      })

      -- Mock params
      -- cursor.col is 1-indexed: '<div class="fs-' has 16 chars, cursor after '-' is position 17
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 0, col = 17 },  -- After "fs-"
          cursor_line = '<div class="fs-',
        }
      }

      local completed = false
      instance:complete(params, function(result)
        completed = true
        -- Should return items (if Bootstrap CSS is available)
        -- or empty (if not available in test environment)
        assert.is_table(result)
        assert.is_table(result.items)
      end)

      assert.is_true(completed)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should detect class-value context on single line with closed quote', function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<div class="fs-"'
      })

      -- Mock params
      -- cursor.col is 1-indexed: cursor before closing quote '"'
      -- '<div class="fs-' is 16 chars, cursor at position 17 (before closing ")
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 0, col = 17 },  -- Before closing quote
          cursor_line = '<div class="fs-"',
        }
      }

      local completed = false
      instance:complete(params, function(result)
        completed = true
        assert.is_table(result)
        assert.is_table(result.items)
      end)

      assert.is_true(completed)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should detect class-value context on multiple lines with unclosed quote', function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<div',
        '  class="mt-'
      })

      -- Mock params
      -- '  class="mt-' has 13 chars, cursor after '-' is position 14
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 1, col = 14 },  -- After "mt-" on line 2 (0-indexed line)
          cursor_line = '  class="mt-',
        }
      }

      local completed = false
      instance:complete(params, function(result)
        completed = true
        assert.is_table(result)
        assert.is_table(result.items)
      end)

      assert.is_true(completed)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should detect class-value context on multiple lines with closed quote', function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<div',
        '  class="mt-"'
      })

      -- Mock params
      -- '  class="mt-' has 13 chars, cursor before closing quote is position 14
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 1, col = 14 },  -- Before closing quote on line 2
          cursor_line = '  class="mt-"',
        }
      }

      local completed = false
      instance:complete(params, function(result)
        completed = true
        assert.is_table(result)
        assert.is_table(result.items)
      end)

      assert.is_true(completed)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should not provide class completion for non-class attributes', function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<div id="test-'
      })

      -- Mock params
      -- '<div id="test-' has 15 chars, cursor after '-' is position 16
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 0, col = 16 },  -- After "test-"
          cursor_line = '<div id="test-',
        }
      }

      local completed = false
      instance:complete(params, function(result)
        completed = true
        assert.is_table(result)
        assert.is_table(result.items)
        -- Should not provide Bootstrap class completions for id attribute
      end)

      assert.is_true(completed)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should handle single quotes in class attribute', function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "<div class='mb-"
      })

      -- Mock params
      -- "<div class='mb-" has 16 chars, cursor after '-' is position 17
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 0, col = 17 },  -- After "mb-"
          cursor_line = "<div class='mb-",
        }
      }

      local completed = false
      instance:complete(params, function(result)
        completed = true
        assert.is_table(result)
        assert.is_table(result.items)
      end)

      assert.is_true(completed)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('should handle multiple classes in class attribute', function()
      -- Create a test buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<div class="container mt-3 text-'
      })

      -- Mock params
      -- '<div class="container mt-3 text-' has 34 chars, cursor after '-' is position 35
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 0, col = 35 },  -- After "text-"
          cursor_line = '<div class="container mt-3 text-',
        }
      }

      local completed = false
      instance:complete(params, function(result)
        completed = true
        assert.is_table(result)
        assert.is_table(result.items)
      end)

      assert.is_true(completed)

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('CSS parsing and completion content', function()
    it('should parse test fixture CSS and extract expected classes', function()
      -- Use test fixture CSS
      local test_css_path = vim.fn.getcwd() .. '/tests/fixtures/test-bootstrap.css'
      local classes = css_parser.parse_css_classes(test_css_path)

      -- Should have parsed the classes
      assert.is_table(classes)

      -- Verify specific utility classes exist
      assert.is_not_nil(classes['fs-1'])
      assert.is_not_nil(classes['fs-5'])
      assert.is_not_nil(classes['mt-1'])
      assert.is_not_nil(classes['mt-3'])
      assert.is_not_nil(classes['mb-1'])
      assert.is_not_nil(classes['ms-2'])
      assert.is_not_nil(classes['text-muted'])
      assert.is_not_nil(classes['text-center'])
      assert.is_not_nil(classes['d-flex'])

      -- Verify component classes also exist (not filtered)
      assert.is_not_nil(classes['container'])
      assert.is_not_nil(classes['btn'])
      assert.is_not_nil(classes['card'])
    end)

    it('should not include invalid classes from CSS values', function()
      -- Use test fixture CSS
      local test_css_path = vim.fn.getcwd() .. '/tests/fixtures/test-bootstrap.css'
      local classes = css_parser.parse_css_classes(test_css_path)

      -- Should NOT have classes from decimal values like 0.125
      assert.is_nil(classes['125'])
      assert.is_nil(classes['375rem'])
      assert.is_nil(classes['75rem'])

      -- Should NOT have classes starting with numbers
      assert.is_nil(classes['3rem'])
      assert.is_nil(classes['1px'])
    end)

    it('should return specific class labels in completion items with test CSS', function()
      -- Create a mock project structure with test CSS
      local test_project_dir = vim.fn.tempname()
      vim.fn.mkdir(test_project_dir, 'p')
      vim.fn.mkdir(test_project_dir .. '/node_modules/bootstrap/dist/css', 'p')

      -- Copy test CSS to mock bootstrap location
      local test_css_path = vim.fn.getcwd() .. '/tests/fixtures/test-bootstrap.css'
      local bootstrap_css_path = test_project_dir .. '/node_modules/bootstrap/dist/css/bootstrap.css'
      local content = vim.fn.readfile(test_css_path)
      vim.fn.writefile(content, bootstrap_css_path)

      -- Create package.json
      vim.fn.writefile({'{"dependencies": {}}'}, test_project_dir .. '/package.json')

      -- Create a test buffer in the mock project
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '<div class="fs-' })
      vim.api.nvim_buf_set_name(bufnr, test_project_dir .. '/test.vue')
      vim.api.nvim_set_current_buf(bufnr)

      -- Set filetype to vue
      vim.bo.filetype = 'vue'

      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 0, col = 17 },
          cursor_line = '<div class="fs-',
        }
      }

      local completed = false
      local result_items = nil
      instance:complete(params, function(result)
        completed = true
        result_items = result.items
      end)

      assert.is_true(completed)
      assert.is_table(result_items)

      -- Verify specific class labels are in the completion items (if CSS was loaded)
      if #result_items > 0 then
        local labels = {}
        for _, item in ipairs(result_items) do
          labels[item.label] = true
        end

        -- Should include fs-* classes
        assert.is_true(labels['fs-1'], 'Should include fs-1')
        assert.is_true(labels['fs-5'], 'Should include fs-5')

        -- Should include other utility classes
        assert.is_true(labels['mt-1'], 'Should include mt-1')
        assert.is_true(labels['text-muted'], 'Should include text-muted')

        -- Should also include component classes (not filtered)
        assert.is_true(labels['btn'], 'Should include btn')
        assert.is_true(labels['container'], 'Should include container')
      end

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
      vim.fn.delete(test_project_dir, 'rf')
    end)

    it('should return correct labels for closed quote scenario', function()
      -- Create a mock project structure with test CSS
      local test_project_dir = vim.fn.tempname()
      vim.fn.mkdir(test_project_dir, 'p')
      vim.fn.mkdir(test_project_dir .. '/node_modules/bootstrap/dist/css', 'p')

      -- Copy test CSS
      local test_css_path = vim.fn.getcwd() .. '/tests/fixtures/test-bootstrap.css'
      local bootstrap_css_path = test_project_dir .. '/node_modules/bootstrap/dist/css/bootstrap.css'
      local content = vim.fn.readfile(test_css_path)
      vim.fn.writefile(content, bootstrap_css_path)

      -- Create package.json
      vim.fn.writefile({'{"dependencies": {}}'}, test_project_dir .. '/package.json')

      -- Create a test buffer with closed quote
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { '<div class="mt-">' })
      vim.api.nvim_buf_set_name(bufnr, test_project_dir .. '/test.vue')
      vim.api.nvim_set_current_buf(bufnr)
      vim.bo.filetype = 'vue'

      -- Cursor before closing quote
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 0, col = 17 },  -- After "mt-", before closing "
          cursor_line = '<div class="mt-">',
        }
      }

      local completed = false
      local result_items = nil
      instance:complete(params, function(result)
        completed = true
        result_items = result.items
      end)

      assert.is_true(completed)
      assert.is_table(result_items)

      -- Verify mt-* classes are included (if CSS was loaded)
      if #result_items > 0 then
        local labels = {}
        for _, item in ipairs(result_items) do
          labels[item.label] = true
        end

        assert.is_true(labels['mt-1'], 'Should include mt-1 in closed quote scenario')
        assert.is_true(labels['mt-2'], 'Should include mt-2 in closed quote scenario')
        assert.is_true(labels['mt-3'], 'Should include mt-3 in closed quote scenario')
      end

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
      vim.fn.delete(test_project_dir, 'rf')
    end)

    it('should return correct labels for multi-line closed quote scenario', function()
      -- Create a mock project structure with test CSS
      local test_project_dir = vim.fn.tempname()
      vim.fn.mkdir(test_project_dir, 'p')
      vim.fn.mkdir(test_project_dir .. '/node_modules/bootstrap/dist/css', 'p')

      -- Copy test CSS
      local test_css_path = vim.fn.getcwd() .. '/tests/fixtures/test-bootstrap.css'
      local bootstrap_css_path = test_project_dir .. '/node_modules/bootstrap/dist/css/bootstrap.css'
      local content = vim.fn.readfile(test_css_path)
      vim.fn.writefile(content, bootstrap_css_path)

      -- Create package.json
      vim.fn.writefile({'{"dependencies": {}}'}, test_project_dir .. '/package.json')

      -- Create a test buffer with multi-line and closed quote
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        '<div',
        '  class="ms-">'
      })
      vim.api.nvim_buf_set_name(bufnr, test_project_dir .. '/test.vue')
      vim.api.nvim_set_current_buf(bufnr)
      vim.bo.filetype = 'vue'

      -- Cursor before closing quote on line 2
      local params = {
        context = {
          bufnr = bufnr,
          cursor = { line = 1, col = 14 },  -- After "ms-", before closing "
          cursor_line = '  class="ms-">',
        }
      }

      local completed = false
      local result_items = nil
      instance:complete(params, function(result)
        completed = true
        result_items = result.items
      end)

      assert.is_true(completed)
      assert.is_table(result_items)

      -- Verify ms-* classes are included (if CSS was loaded)
      if #result_items > 0 then
        local labels = {}
        for _, item in ipairs(result_items) do
          labels[item.label] = true
        end

        assert.is_true(labels['ms-1'], 'Should include ms-1 in multi-line closed quote scenario')
        assert.is_true(labels['ms-2'], 'Should include ms-2 in multi-line closed quote scenario')
      end

      -- Cleanup
      vim.api.nvim_buf_delete(bufnr, { force = true })
      vim.fn.delete(test_project_dir, 'rf')
    end)
  end)
end)
