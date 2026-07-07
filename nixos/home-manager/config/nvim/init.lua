-- Set <space> as the leader key before plugins and mappings load
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

require("options")
require("keymaps")
require("autocmds")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end
---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require("lazy").setup({
	-- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
	"tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically

	-- NOTE: Plugins can also be added by using a table,
	-- with the first argument being the link and the following
	-- keys can be used to configure plugin behavior/loading/etc.
	--
	-- Use `opts = {}` to force a plugin to be loaded.
	--

	-- Here is a more advanced example where we pass configuration
	-- options to `gitsigns.nvim`. This is equivalent to the following Lua:
	--    require('gitsigns').setup({ ... })
	--
	-- See `:help gitsigns` to understand what the configuration keys do

	-- NOTE: Plugins can also be configured to run Lua code when they are loaded.
	--
	-- This is often very useful to both group configuration, as well as handle
	-- lazy loading plugins that don't need to be loaded immediately at startup.
	--
	-- For example, in the following configuration, we use:
	--  event = 'VimEnter'
	--
	-- which loads which-key before all the UI elements are loaded. Events can be
	-- normal autocommands events (`:help autocmd-events`).
	--
	-- Then, because we use the `config` key, the configuration only runs
	-- after the plugin has been loaded:
	--  config = function() ... end

	-- NOTE: Plugins can specify dependencies.
	--
	-- The dependencies are proper plugin specifications as well - anything
	-- you do for a plugin at the top level, you can do for a dependency.
	--
	-- Use the `dependencies` key to specify the dependencies of a particular plugin

	{ -- Fuzzy Finder (files, lsp, etc) — fzf-lua replaces telescope.nvim
		"ibhagwan/fzf-lua",
		event = "VimEnter",
		dependencies = {
			-- Useful for getting pretty icons, but requires a Nerd Font.
			{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
		},
		config = function()
			-- fzf-lua is a fuzzy finder built on the `fzf` binary (provided system-wide
			-- by Home Manager). It also uses `fd`, `rg` and `bat` for listing, grep and
			-- preview. Being pure Lua (shelling out to `fzf`), it needs no `build` step
			-- (unlike telescope-fzf-native which required `make`).
			--
			-- The built-in "telescope" profile replicates telescope's borders/prompt
			-- layout so the UI stays familiar.
			local fzf_actions = require("fzf-lua.actions")
			require("fzf-lua").setup({
				"telescope",
				keymap = {
					-- fzf binds. The leading `true` inherits ALL default binds, incl. the
					-- telescope profile's ctrl-d/ctrl-u (preview-page down/up) and ctrl-q
					-- (select-all+accept). On top of that we add:
					--   ctrl-c -> abort (telescope's <C-c>-to-close)
					--   ctrl-j -> down  (next item, like telescope)
					--   ctrl-k -> up    (prev item, like telescope)
					-- Preview scroll: ctrl-d (down) / ctrl-u (up), inherited from the profile.
					fzf = {
						true,
						["ctrl-c"] = "abort",
						["ctrl-j"] = "down",
						["ctrl-k"] = "up",
					},
				},
				buffers = {
					-- The telescope profile rebinds ctrl-d = buf_del in the buffers picker AND
					-- disables the Neovim-side `keymap.builtin["<C-d>"]` (= false) to avoid a clash.
					-- But the buffers picker uses the BUILTIN (Neovim) previewer, whose scrolling is
					-- driven by `keymap.builtin`, not `keymap.fzf` -- so with builtin ctrl-d disabled,
					-- ctrl-d reaches fzf (no native preview to scroll) and does nothing. Re-enable
					-- builtin ctrl-d here to scroll the preview like every other picker, and move
					-- buffer-delete to ctrl-x.
					keymap = {
						builtin = {
							["<C-d>"] = "preview-page-down",
						},
					},
					actions = {
						-- `false` drops the profile's ctrl-d = buf_del. A bare string action like
						-- "preview-page-down" would fail hide.enrich's assertion (actions must be a
						-- {fn=...} table or false); preview scroll is handled by keymap.builtin above.
						["ctrl-d"] = false,
						["ctrl-x"] = { fn = fzf_actions.buf_del, reload = true },
					},
				},
			})

			-- Register fzf-lua as the UI for vim.ui.select (replaces telescope-ui-select)
			require("fzf-lua").register_ui_select()

			local fzf = require("fzf-lua")
			vim.keymap.set("n", "<leader>sh", fzf.helptags, { desc = "[S]earch [H]elp" })
			vim.keymap.set("n", "<leader>sk", fzf.keymaps, { desc = "[S]earch [K]eymaps" })
			vim.keymap.set("n", "<leader>sf", fzf.files, { desc = "[S]earch [F]iles" })
			vim.keymap.set("n", "<leader>ss", fzf.builtin, { desc = "[S]earch [S]elect fzf-lua" })
			vim.keymap.set("n", "<leader>sw", fzf.grep_cword, { desc = "[S]earch current [W]ord" })
			vim.keymap.set("n", "<leader>sg", fzf.live_grep, { desc = "[S]earch by [G]rep" })
			vim.keymap.set("n", "<leader>sd", fzf.diagnostics_workspace, { desc = "[S]earch [D]iagnostics" })
			vim.keymap.set("n", "<leader>sr", fzf.resume, { desc = "[S]earch [R]esume" })
			vim.keymap.set("n", "<leader>s.", fzf.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
			vim.keymap.set("n", "<leader><leader>", fzf.buffers, { desc = "[ ] Find existing buffers" })

			-- Slightly advanced example of overriding default behavior and theme
			vim.keymap.set("n", "<leader>/", function()
				-- fzf-lua's `blines` lists/fuzzy-filters the current buffer's lines,
				-- equivalent to telescope's current_buffer_fuzzy_find.
				-- Small centered window, no previewer — matches the dropdown theme.
				fzf.blines({
					previewer = false,
					winopts = { height = 0.4, width = 0.6, row = 0.5, col = 0.5 },
				})
			end, { desc = "[/] Fuzzily search in current buffer" })

			-- It's also possible to pass additional configuration options.
			vim.keymap.set("n", "<leader>s/", function()
				-- No `prompt=` override: keep fzf-lua's default cwd-based prompt
				-- (its `prompt` replaces the whole prompt, unlike telescope's title).
				fzf.live_grep({
					grep_open_files = true,
				})
			end, { desc = "[S]earch [/] in Open Files" })

			-- Shortcut for searching your Neovim configuration files
			vim.keymap.set("n", "<leader>sn", function()
				fzf.files({ cwd = vim.fn.stdpath("config") })
			end, { desc = "[S]earch [N]eovim files" })
		end,
	},

	{ -- Autoformat
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>f",
				function()
					require("conform").format({ async = true, lsp_fallback = true })
				end,
				mode = "",
				desc = "[F]ormat buffer",
			},
		},
		opts = {
			notify_on_error = true,
			format_on_save = function(bufnr)
				-- Disable "format_on_save lsp_fallback" for languages that don't
				-- have a well standardized coding style. You can add additional
				-- languages here or re-enable it for the disabled ones.
				local disable_filetypes = { c = true, cpp = true }
				return {
					timeout_ms = 5000,
					lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
				}
			end,
			formatters_by_ft = {
				lua = { "stylua" },
				-- Conform can also run multiple formatters sequentially
				-- python = { 'isort', 'black' },
				python = { "black" },
				json = { "biome" },
				-- You can use a sub-list to tell conform to run *until* a formatter
				-- is found.
				-- javascript = { { "prettierd", "prettier" } },
				html = { "prettierd" },
			},
		},
	},

	{ -- Autocompletion Plugin Definition (using lazy.nvim)
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			-- ... your dependencies ...
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-path",
		},
		-- vvvvvvvv THIS IS THE CONFIG FUNCTION FOR NVIM-CMP vvvvvvvvvv
		config = function()
			-- See `:help cmp`
			local cmp = require("cmp")

			-- *** Main cmp setup ***
			-- Define your GLOBAL cmp settings here
			cmp.setup({ -- <----------------------------------- START of main cmp.setup call
				snippet = {
					-- ... snippet config ...
				},
				completion = { completeopt = "menu,menuone,noinsert" },
				mapping = cmp.mapping.preset.insert({
					-- ... your mappings ...
				}),
				sources = cmp.config.sources({
					-- Give Supermaven high priority
					-- { name = "supermaven", group_index = 1, priority = 100 },

					{ name = "nvim_lsp", group_index = 1 },
					{ name = "path", group_index = 3 },
					{ name = "buffer", group_index = 3 },
					{ name = "lazydev", group_index = 0 },
				}),
			}) -- <-------------------------------------------- END of main cmp.setup call

			-- *** Filetype specific setup ***
			-- This call modifies the setup for specific filetypes
			-- It MUST come AFTER the main cmp.setup call above
			-- >>>>>>>>>>>>>> PUT IT RIGHT HERE <<<<<<<<<<<<<<<<<<<<<<
			cmp.setup.filetype({ "sql", "mysql", "psql" }, {
				sources = cmp.config.sources({
					-- Order sources specifically for SQL files
					{ name = "vim-dadbod-completion" },
					{ name = "buffer" },
					{ name = "path" },
				}),
			})
			-- >>>>>>>>>>>>>> END OF FILETYPE SETUP <<<<<<<<<<<<<<<<<<<
		end, -- <----------- END OF THE CONFIG FUNCTION FOR NVIM-CMP
		-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	}, -- <------------- END OF NVIM-CMP PLUGIN DEFINITION


	-- Highlight todo, notes, etc in comments
	{
		"folke/todo-comments.nvim",
		event = "VimEnter",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = { signs = false },
	},

	{ -- Collection of various small independent plugins/modules
		"echasnovski/mini.nvim",
		config = function()
			-- Better Around/Inside textobjects
			--
			-- Examples:
			--  - va)  - [V]isually select [A]round [)]paren
			--  - yinq - [Y]ank [I]nside [N]ext [Q]uote
			--  - ci'  - [C]hange [I]nside [']quote
			require("mini.ai").setup({ n_lines = 500 })

			-- Add/delete/replace surroundings (brackets, quotes, etc.)
			--
			-- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
			-- - sd'   - [S]urround [D]elete [']quotes
			-- - sr)'  - [S]urround [R]eplace [)] [']
			require("mini.surround").setup()

			-- Simple and easy statusline.
			--  You could remove this setup call if you don't like it,
			--  and try some other statusline plugin
			-- kajdo disable
			-- local statusline = require 'mini.statusline'
			-- set use_icons to true if you have a Nerd Font
			-- statusline.setup { use_icons = vim.g.have_nerd_font }

			-- You can configure sections in the statusline by overriding their
			-- default behavior. For example, here we set the section for
			-- cursor location to LINE:COLUMN
			---@diagnostic disable-next-line: duplicate-set-field
			-- statusline.section_location = function()
			--   return '%2l:%-2v'
			-- end

			-- ... and there is more!
			--  Check out: https://github.com/echasnovski/mini.nvim
		end,
	},
	{ import = "custom.plugins" },
}, {
	lockfile = vim.fn.stdpath("data") .. "/lazy/lazy-lock.json",
	ui = {
		-- If you are using a Nerd Font: set icons to an empty table which will use the
		-- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘",
			config = "🛠",
			event = "📅",
			ft = "📂",
			init = "⚙",
			keys = "🗝",
			plugin = "🔌",
			runtime = "💻",
			require = "🌙",
			source = "📄",
			start = "🚀",
			task = "📌",
			lazy = "💤 ",
		},
	},
})

require("lsp")

-- Add nix-installed tree-sitter parsers and queries to runtimepath
local ts_path = vim.env.HOME .. "/nvim-treesitter-parsers"
if vim.fn.isdirectory(ts_path) == 1 then
	-- Queries from the nix plugin live under runtime/queries.
	vim.opt.rtp:append(ts_path .. "/runtime")
	for _, name in ipairs(vim.fn.readdir(ts_path .. "/parser")) do
		if name:match("%.so$") then
			local lang = name:gsub("%.so$", "")
			vim.treesitter.language.add(lang, { path = ts_path .. "/parser/" .. name })
		end
	end
	-- Shell buffers use the "sh" filetype, but the parser package is named "bash".
	vim.treesitter.language.register("bash", { "sh", "zsh" })
end

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
