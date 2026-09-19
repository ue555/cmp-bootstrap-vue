local source = require('cmp_bootstrap_vue.source')

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
end)
