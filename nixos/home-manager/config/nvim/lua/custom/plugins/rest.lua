-- rest.lua

return {
	{
		"diepm/vim-rest-console",
		config = function()
			-- Optional configuration can be added here
			-- For instance, you might want to customize key mappings
			vim.g.rest_console = {
				-- Default configuration options for vim-rest-console
				-- You can customize options here if needed
			}
			vim.g.vrc_response_default_content_type = "application/json"
			vim.g.vrc_output_buffer_name = "_OUTPUT.json"

			-- Keybindings for convenience (optional)
			-- You can set your own keybindings here
			vim.api.nvim_set_keymap("n", "<leader>rr", ":call VrcQuery()<CR>", { noremap = true, silent = true })
		end,
	},
}
