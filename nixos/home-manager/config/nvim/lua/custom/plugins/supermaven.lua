-- ~/.config/nvim/lua/custom/plugins/supermaven.lua
return {
	"supermaven-inc/supermaven-nvim",
	enabled = false,
	-- Load it reasonably early, but maybe after cmp if you prefer strict ordering
	-- Or just use lazy loading triggered by entering a buffer
	event = "BufEnter",
	config = function()
		-- Basic setup using default options.
		-- You can add configuration keys here later if needed (e.g., keymaps).
		require("supermaven-nvim").setup({
			-- Example: uncomment and change if you don't want Tab
			-- keymaps = {
			--   accept_suggestion = "<C-Space>", -- Example: use Ctrl+Space instead of Tab
			--   clear_suggestion = "<Esc>",      -- Example: use Escape to clear
			--   accept_word = "<C-j>",           -- Default is fine
			-- },
			-- log_level = "debug", -- Use if needed for troubleshooting
		})
		print("Supermaven plugin configured.") -- Add a print statement for confirmation
	end,
}
