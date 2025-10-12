-- rest.lua

return {
	"chrisgrieser/nvim-origami",
	enabled = true,
	event = "VeryLazy",
	opts = {}, -- needed even when using default config

	-- recommended: disable vim's auto-folding
	init = function()
		vim.opt.foldlevel = 99
		vim.opt.foldlevelstart = 99
		vim.keymap.set("n", "<C-a>", function()
			require("origami").h()
		end)
		vim.keymap.set("n", "<C-s>", function()
			require("origami").l()
		end)
	end,
}
