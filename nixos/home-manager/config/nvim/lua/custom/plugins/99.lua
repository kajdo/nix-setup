return {
	enabled = false,
	"ThePrimeagen/99",
	config = function()
		local _99 = require("99")

		local cwd = vim.uv.cwd()
		local basename = vim.fs.basename(cwd)

		_99.setup({
			model = "zai-coding-plan/glm-5-turbo",
			logger = {
				level = _99.DEBUG,
				path = "/tmp/" .. basename .. ".99.debug",
				print_on_error = true,
			},
			tmp_dir = "./tmp",
			completion = {
				source = "cmp",
			},
			md_files = {
				"AGENT.md",
			},
		})

		vim.keymap.set("v", "<leader>9v", function()
			_99.visual()
		end, { desc = "99: AI visual selection" })

		vim.keymap.set("n", "<leader>9x", function()
			_99.stop_all_requests()
		end, { desc = "99: stop all requests" })

		vim.keymap.set("n", "<leader>9s", function()
			_99.search()
		end, { desc = "99: AI search" })

		vim.keymap.set("n", "<leader>99", function()
			_99.vibe()
		end, { desc = "99: AI vibe" })

		vim.keymap.set("n", "<leader>9m", function()
			require("99.extensions.telescope").select_model()
		end, { desc = "99: select model" })

		vim.keymap.set("n", "<leader>9p", function()
			require("99.extensions.telescope").select_provider()
		end, { desc = "99: select provider" })
	end,
}
