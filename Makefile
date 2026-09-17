.PHONY: test
test:
	@echo "Running tests with plenary.nvim..."
	@nvim --headless -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

.PHONY: lint
lint:
	@echo "Linting is not yet configured"
	@echo "Consider adding stylua or luacheck"

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  test  - Run tests with plenary.nvim"
	@echo "  lint  - Run linter (not yet configured)"
	@echo "  help  - Show this help message"
