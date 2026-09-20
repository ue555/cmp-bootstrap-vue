local css_parser = require('cmp_bootstrap_vue.css_parser')

describe('css_parser', function()
  describe('get_class_category', function()
    it('should categorize spacing utilities', function()
      assert.equals('Spacing', css_parser.get_class_category('m-3'))
      assert.equals('Spacing', css_parser.get_class_category('p-2'))
      assert.equals('Spacing', css_parser.get_class_category('mt-5'))
      assert.equals('Spacing', css_parser.get_class_category('mb-1'))
      assert.equals('Spacing', css_parser.get_class_category('mx-auto'))
    end)

    it('should categorize typography utilities', function()
      assert.equals('Typography', css_parser.get_class_category('fs-1'))
      assert.equals('Typography', css_parser.get_class_category('fs-6'))
    end)

    it('should categorize text utilities', function()
      assert.equals('Text', css_parser.get_class_category('text-muted'))
      assert.equals('Text', css_parser.get_class_category('text-center'))
      assert.equals('Text', css_parser.get_class_category('text-primary'))
    end)

    it('should categorize background utilities', function()
      assert.equals('Background', css_parser.get_class_category('bg-primary'))
      assert.equals('Background', css_parser.get_class_category('bg-light'))
    end)

    it('should categorize border utilities', function()
      assert.equals('Border', css_parser.get_class_category('border'))
      assert.equals('Border', css_parser.get_class_category('border-top'))
    end)

    it('should categorize display utilities', function()
      assert.equals('Display', css_parser.get_class_category('d-flex'))
      assert.equals('Display', css_parser.get_class_category('d-none'))
    end)

    it('should categorize flexbox utilities', function()
      assert.equals('Flexbox', css_parser.get_class_category('flex-row'))
      assert.equals('Flexbox', css_parser.get_class_category('justify-content-center'))
      assert.equals('Flexbox', css_parser.get_class_category('align-items-start'))
    end)

    it('should return Utility for unknown classes', function()
      assert.equals('Utility', css_parser.get_class_category('custom-class'))
      assert.equals('Utility', css_parser.get_class_category('unknown'))
    end)
  end)

  describe('get_class_documentation', function()
    it('should generate documentation with category', function()
      local doc = css_parser.get_class_documentation('m-3')
      assert.is_string(doc)
      assert.is_true(doc:match('Category') ~= nil)
      assert.is_true(doc:match('Spacing') ~= nil)
    end)

    it('should include type information for spacing utilities', function()
      local doc = css_parser.get_class_documentation('m-3')
      assert.is_true(doc:match('Margin') ~= nil)

      local doc_p = css_parser.get_class_documentation('p-2')
      assert.is_true(doc_p:match('Padding') ~= nil)
    end)

    it('should include type information for typography utilities', function()
      local doc = css_parser.get_class_documentation('fs-1')
      assert.is_true(doc:match('Font size') ~= nil)
    end)
  end)

  describe('parse_css_classes', function()
    it('should return nil for non-existent file', function()
      local result = css_parser.parse_css_classes('/non/existent/path.css')
      assert.is_nil(result)
    end)

    it('should parse simple CSS file', function()
      -- Create a temporary CSS file for testing
      local temp_file = '/tmp/test-bootstrap.css'
      local f = io.open(temp_file, 'w')
      f:write([[
.fs-1 { font-size: 3rem; }
.fs-2 { font-size: 2.5rem; }
.mb-1 { margin-bottom: 0.25rem; }
.text-muted { color: #6c757d; }
.d-flex { display: flex; }
]])
      f:close()

      local classes = css_parser.parse_css_classes(temp_file)

      assert.is_table(classes)
      assert.is_not_nil(classes['fs-1'])
      assert.is_not_nil(classes['fs-2'])
      assert.is_not_nil(classes['mb-1'])
      assert.is_not_nil(classes['text-muted'])
      assert.is_not_nil(classes['d-flex'])

      -- Cleanup
      os.remove(temp_file)
    end)

    it('should handle compound selectors', function()
      local temp_file = '/tmp/test-bootstrap-compound.css'
      local f = io.open(temp_file, 'w')
      f:write([[
.btn.btn-primary { background: blue; }
.card .card-body { padding: 1rem; }
]])
      f:close()

      local classes = css_parser.parse_css_classes(temp_file)

      assert.is_table(classes)
      assert.is_not_nil(classes['btn'])
      assert.is_not_nil(classes['btn-primary'])
      assert.is_not_nil(classes['card'])
      assert.is_not_nil(classes['card-body'])

      -- Cleanup
      os.remove(temp_file)
    end)

    it('should skip pseudo-classes', function()
      local temp_file = '/tmp/test-bootstrap-pseudo.css'
      local f = io.open(temp_file, 'w')
      f:write([[
.btn:hover { background: blue; }
.link::before { content: "→"; }
.valid { color: green; }
]])
      f:close()

      local classes = css_parser.parse_css_classes(temp_file)

      assert.is_table(classes)
      assert.is_not_nil(classes['btn'])
      assert.is_not_nil(classes['link'])
      assert.is_not_nil(classes['valid'])
      -- Pseudo-classes/elements should not be included as separate entries
      assert.is_nil(classes['hover'])
      assert.is_nil(classes['before'])

      -- Cleanup
      os.remove(temp_file)
    end)

    it('should not extract decimal values from CSS declarations', function()
      local temp_file = '/tmp/test-bootstrap-decimals.css'
      local f = io.open(temp_file, 'w')
      f:write([[
.example {
  opacity: 0.5;
  margin: 0.125rem;
  padding: 0.75em;
}
.valid-class {
  width: 1.5rem;
}
]])
      f:close()

      local classes = css_parser.parse_css_classes(temp_file)

      assert.is_table(classes)
      -- Valid classes should be extracted
      assert.is_not_nil(classes['example'])
      assert.is_not_nil(classes['valid-class'])

      -- Decimal values should NOT be extracted as class names
      assert.is_nil(classes['5'])
      assert.is_nil(classes['125rem'])
      assert.is_nil(classes['75em'])
      assert.is_nil(classes['5rem'])

      -- Cleanup
      os.remove(temp_file)
    end)

    it('should filter out class names starting with numbers', function()
      local temp_file = '/tmp/test-bootstrap-numbers.css'
      local f = io.open(temp_file, 'w')
      f:write([[
.valid-1 { color: red; }
.2invalid { color: blue; }
.3-test { color: green; }
.test-4 { color: yellow; }
]])
      f:close()

      local classes = css_parser.parse_css_classes(temp_file)

      assert.is_table(classes)
      -- Classes not starting with numbers should be extracted
      assert.is_not_nil(classes['valid-1'])
      assert.is_not_nil(classes['test-4'])

      -- Classes starting with numbers should NOT be extracted (invalid CSS)
      assert.is_nil(classes['2invalid'])
      assert.is_nil(classes['3-test'])

      -- Cleanup
      os.remove(temp_file)
    end)

    it('should remove CSS comments before parsing', function()
      local temp_file = '/tmp/test-bootstrap-comments.css'
      local f = io.open(temp_file, 'w')
      f:write([[
/* This is a comment with .fake-class */
.real-class {
  color: red; /* inline comment with .another-fake */
}
/*
  Multi-line comment
  with .multi-fake
*/
.another-real { color: blue; }
]])
      f:close()

      local classes = css_parser.parse_css_classes(temp_file)

      assert.is_table(classes)
      -- Real classes should be extracted
      assert.is_not_nil(classes['real-class'])
      assert.is_not_nil(classes['another-real'])

      -- Classes in comments should NOT be extracted
      assert.is_nil(classes['fake-class'])
      assert.is_nil(classes['another-fake'])
      assert.is_nil(classes['multi-fake'])

      -- Cleanup
      os.remove(temp_file)
    end)

    it('should only extract from selectors, not declarations', function()
      local temp_file = '/tmp/test-bootstrap-selectors-only.css'
      local f = io.open(temp_file, 'w')
      f:write([[
.header .title {
  background: url('.background-image.png');
  content: '.not-a-class';
}
]])
      f:close()

      local classes = css_parser.parse_css_classes(temp_file)

      assert.is_table(classes)
      -- Selector classes should be extracted
      assert.is_not_nil(classes['header'])
      assert.is_not_nil(classes['title'])

      -- Classes in declaration values should NOT be extracted
      assert.is_nil(classes['background-image'])
      assert.is_nil(classes['not-a-class'])

      -- Cleanup
      os.remove(temp_file)
    end)
  end)
end)
