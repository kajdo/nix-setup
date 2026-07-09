-- LSP Configuration using Neovim 0.11+ native vim.lsp.config API
-- All LSP servers are provided via Home Manager (dev-tools.nix).

-- Capabilities: Neovim merges whatever we provide with the full defaults
-- (vim.tbl_deep_extend('force', make_client_capabilities(), ...) in client.lua),
-- so formatting (textDocument/formatting, used by conform's lsp_fallback) and all
-- other standard capabilities are always present. No explicit wiring is needed.
-- Completion uses the built-in vim.lsp.completion (enabled per-buffer in LspAttach).

-- Individual server configurations

vim.lsp.config('ts_ls', {
	cmd = { "typescript-language-server", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
})
vim.lsp.enable('ts_ls')

vim.lsp.config('pyright', {
	cmd = { "pyright-langserver", "--stdio" },
	filetypes = { "python" },
})
vim.lsp.enable('pyright')

vim.lsp.config('bashls', {
	cmd = { "bash-language-server", "start" },
	filetypes = { "sh", "bash", "zsh" },
})
vim.lsp.enable('bashls')

vim.lsp.config('dockerls', {
	cmd = { "docker-langserver", "--stdio" },
	filetypes = { "dockerfile" },
})
vim.lsp.enable('dockerls')

vim.lsp.config('yamlls', {
	cmd = { "yaml-language-server", "--stdio" },
	filetypes = { "yaml", "yml" },
})
vim.lsp.enable('yamlls')

vim.lsp.config('vimls', {
	cmd = { "vim-language-server", "--stdio" },
	filetypes = { "vim" },
})
vim.lsp.enable('vimls')

vim.lsp.config('eslint', {
	cmd = { "vscode-eslint-language-server", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
})
vim.lsp.enable('eslint')

vim.lsp.config('dartls', {
	cmd = { "dart", "language-server", "--protocol=lsp" },
	filetypes = { "dart" },
})
vim.lsp.enable('dartls')

vim.lsp.config('nixd', {
	cmd = { "nixd" },
	filetypes = { "nix" },
})
vim.lsp.enable('nixd')

vim.lsp.config('lua_ls', {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
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

		local client = vim.lsp.get_client_by_id(event.data.client_id)

		-- Native LSP completion (Neovim 0.11+ vim.lsp.completion), replaces nvim-cmp.
		-- Autotriggered on the server's trigger characters; <C-Space> triggers it
		-- manually (mapped in keymaps.lua).
		if client and client:supports_method("textDocument/completion") then
			vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
		end

		-- Document highlights (CursorHold)
		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
			local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.document_highlight,
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
