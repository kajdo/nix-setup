-- Lazy
return {
	"jackMort/ChatGPT.nvim",
	enabled = false,
	event = "VeryLazy",
	config = function()
		require("chatgpt").setup({
			chat = {
				keymaps = {
					close = "<C-c>",
					yank_last = "<C-y>",
					yank_last_code = "<C-k>",
					scroll_up = "<C-u>",
					scroll_down = "<C-d>",
					new_session = "<C-n>",
					cycle_windows = "<S-Tab>",
					cycle_modes = "<C-f>",
					next_message = "<C-j>",
					prev_message = "<C-k>",
					select_session = "<Space>",
					rename_session = "r",
					delete_session = "d",
					draft_message = "<C-r>",
					edit_message = "e",
					delete_message = "d",
					toggle_settings = "<C-o>",
					toggle_sessions = "<C-p>",
					toggle_help = "<C-h>",
					toggle_message_role = "<C-r>",
					toggle_system_role_open = "<C-s>",
					stop_generating = "<C-x>",
				},
			},
			edit_with_instructions = {
				diff = false,
				keymaps = {
					close = "<C-c>",
					accept = "<C-y>",
					toggle_diff = "<C-d>",
					toggle_settings = "<C-o>",
					toggle_help = "<C-h>",
					cycle_windows = "<S-Tab>",
					use_output_as_input = "<C-i>",
				},
			},
			-- this config assumes you have OPENAI_API_KEY environment variable set
			openai_params = {
				-- NOTE: model can be a function returning the model name
				-- this is useful if you want to change the model on the fly
				-- using commands
				-- Example:
				-- model = function()
				--     if some_condition() then
				--         return "gpt-4-1106-preview"
				--     else
				--         return "gpt-3.5-turbo"
				--     end
				-- end,
				-- model = 'gpt-4-1106-preview',
				-- model = 'gpt-4o-mini',
				model = "gpt-4o-mini",
				frequency_penalty = 0,
				presence_penalty = 0,
				max_tokens = 4095,
				temperature = 0.2,
				top_p = 0.1,
				n = 1,
			},
		})
	end,
	dependencies = {
		"MunifTanjim/nui.nvim",
		"nvim-lua/plenary.nvim",
		"folke/trouble.nvim",
		"nvim-telescope/telescope.nvim",
	},
}
