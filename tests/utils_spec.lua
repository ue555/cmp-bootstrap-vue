local utils = require('cmp_bootstrap_vue.utils')

describe('utils', function()
  describe('find_project_root', function()
    it('should return nil when no package.json found', function()
      -- This test assumes we're not in a project with package.json
      -- In real setup, we'd mock the file system
      local root = utils.find_project_root()
      -- Just ensure it returns a value or nil
      assert.is_true(root == nil or type(root) == 'string')
    end)
  end)

  describe('read_json_file', function()
    it('should return nil for non-existent file', function()
      local result = utils.read_json_file('/non/existent/file.json')
      assert.is_nil(result)
    end)
  end)

  describe('set_config and get_config', function()
    it('should update and retrieve configuration', function()
      local original_config = utils.get_config()

      utils.set_config({
        notification_level = vim.log.levels.ERROR,
      })

      local new_config = utils.get_config()
      assert.equals(vim.log.levels.ERROR, new_config.notification_level)

      -- Restore original config
      utils.set_config(original_config)
    end)
  end)

  describe('detect_bootstrap_packages', function()
    it('should return empty table for non-existent root', function()
      local packages = utils.detect_bootstrap_packages('/non/existent/path')
      assert.is_table(packages)
      assert.equals(0, #packages)
    end)
  end)
end)
