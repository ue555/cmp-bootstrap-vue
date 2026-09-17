-- Auto-register the source with nvim-cmp if available
local ok, cmp = pcall(require, 'cmp')

if ok then
  local source = require('cmp_bootstrap_vue.source')
  cmp.register_source('bootstrap-vue', source.new())
end
