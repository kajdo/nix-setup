return {
	{ -- Useful plugin to show you pending keybinds.
		"folke/which-key.nvim",
		event = "VimEnter", -- Sets the loading event to 'VimEnter'
		config = function() -- This is the function that runs, AFTER loading
			-- require('which-key').setup()
			-- kajdo -- unset icons in whichkey
			require("which-key").setup({
				icons = {
					mappings = false,
				},
			})

			-- Document existing key chains
			require("which-key").add({
				{ "<leader>c", group = "[C]ode" },
				{ "<leader>b", group = "[B]uffer" },
				{ "<leader>d", group = "[D]ocument" },
				{ "<leader>l", group = "[L]SP" },
				{ "<leader>r", group = "[R]ename" },
				{ "<leader>s", group = "[S]earch" },
				{ "<leader>w", group = "[W]orkspace" },
				{ "<leader>t", group = "[T]oggle" },
				-- { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
			})
		end,
	},
}
