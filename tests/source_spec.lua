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
end)
