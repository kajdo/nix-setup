-- LSP Configuration using Neovim 0.11+ native vim.lsp.config API
-- All LSP servers are provided via Home Manager (dev-tools.nix).

-- Global default capabilities for nvim-cmp integration
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

vim.lsp.config('*', {
	capabilities = capabilities,
})

-- Individual server configurations

vim.lsp.config('ts_ls', {
	cmd = { "typescript-language-server", "--stdio" },
})
vim.lsp.enable('ts_ls')

vim.lsp.config('pyright', {
	cmd = { "pyright-langserver", "--stdio" },
})
vim.lsp.enable('pyright')

vim.lsp.config('bashls', {
	cmd = { "bash-language-server", "start" },
})
vim.lsp.enable('bashls')

vim.lsp.config('dockerls', {
	cmd = { "docker-langserver", "--stdio" },
})
vim.lsp.enable('dockerls')

vim.lsp.config('yamlls', {
	cmd = { "yaml-language-server", "--stdio" },
})
vim.lsp.enable('yamlls')

vim.lsp.config('vimls', {
	cmd = { "vim-language-server", "--stdio" },
})
vim.lsp.enable('vimls')

vim.lsp.config('eslint', {
	cmd = { "vscode-eslint-language-server", "--stdio" },
})
vim.lsp.enable('eslint')

vim.lsp.config('dartls', {
	cmd = { "dart", "language-server", "--protocol=lsp" },
})
vim.lsp.enable('dartls')

vim.lsp.config('nixd', {
	cmd = { "nixd" },
})
vim.lsp.enable('nixd')

vim.lsp.config('lua_ls', {
	cmd = { "lua-language-server" },
	settings = {
		Lua = {
			completion = {
				callSnippet = "Replace",
			},
			diagnostics = {
				globals = { "vim" },
				disable = { "missing-fields" },
			},
			workspace = {
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
				},
			},
		},
	},
})
vim.lsp.enable('lua_ls')

-- Virtual text diagnostics are handled by tiny-inline-diagnostic.nvim
vim.diagnostic.config({ virtual_text = false })

-- LspAttach: configure keymaps and highlights per buffer
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end

		-- Navigation
		map("gd", require("fzf-lua").lsp_definitions, "[G]oto [D]efinition")
		map("gr", require("fzf-lua").lsp_references, "[G]oto [R]eferences")
		map("gI", require("fzf-lua").lsp_implementations, "[G]oto [I]mplementation")
		map("<leader>D", require("fzf-lua").lsp_typedefs, "Type [D]efinition")
		map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

		-- Symbols
		map("<leader>ds", require("fzf-lua").lsp_document_symbols, "[D]ocument [S]ymbols")
		map("<leader>ws", require("fzf-lua").lsp_live_workspace_symbols, "[W]orkspace [S]ymbols")

		-- Refactor
		map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
		map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")

		-- Document highlights (CursorHold)
		-- Wrapped in pcall because some servers (notably ts_ls) advertise
		-- documentHighlight support but can fail on certain projects.
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
			local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = function()
					pcall(vim.lsp.buf.document_highlight)
				end,
			})
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.clear_references,
			})
			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
				callback = function(event2)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
				end,
			})
		end

		-- Toggle inlay hints
		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
			map("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
			end, "[T]oggle Inlay [H]ints")
		end
	end,
})

-- vim: ts=2 sts=2 sw=2 et
