-- [[ Basic Autocommands ]]
-- See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
-- Try it with `yap` in normal mode
-- See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Start tree-sitter for common filetypes
vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"bash",
		"sh",
		"diff",
		"html",
		"json",
		"yaml",
		"css",
		"dart",
		"python",
		"javascript",
		"typescript",
		"markdown",
		"query",
		"nix",
		"lua",
		"vim",
	},
	callback = function(ev)
		vim.treesitter.start(ev.buf)
	end,
})

-- Stop tree-sitter for large JSON files (performance)
vim.api.nvim_create_autocmd("FileType", {
	pattern = "json",
	callback = function()
		vim.treesitter.stop()
	end,
})

-- Custom command: sudo write the current buffer
vim.api.nvim_create_user_command("Sudowrite", function()
	local current_file = vim.fn.expand("%")
	local success = vim.cmd("w !sudo tee " .. current_file .. " > /dev/null")
	if not success then
		print("Failed to save file with sudo.")
	else
		print("File saved with sudo.")
	end
end, {})

-- vim: ts=2 sts=2 sw=2 et
