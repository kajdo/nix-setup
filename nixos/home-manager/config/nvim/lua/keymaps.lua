-- [[ Basic Keymaps ]]
-- See `:help vim.keymap.set()`

-- Clear search highlights with <Esc>
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\\><C-n>
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Disable arrow keys in normal mode (learn vim motions)
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
-- Use CTRL+<hjkl> to switch between windows
-- See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- Quick escape from insert mode
vim.keymap.set("i", "jk", "<Esc>", { desc = "jk to escape from insert mode" })
vim.keymap.set("i", "kj", "<Esc>", { desc = "kj to escape from insert mode" })

-- Open configuration file
vim.keymap.set("n", "<leader>lc", ":e $MYVIMRC<CR>", { desc = "open configuration file" })

-- Toggle file explorer
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "toggle explorer" })

-- Buffer handling

-- Helper: close current buffer, switch to lowest-numbered other buffer
local function close_current_buffer()
	local current_buf = vim.api.nvim_get_current_buf()
	local buffers = vim.api.nvim_list_bufs()

	local lowest_buf = nil
	for _, buf in ipairs(buffers) do
		if buf ~= current_buf and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			local buf_ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
			if buf_ft ~= "NvimTree" then
				if not lowest_buf or buf < lowest_buf then
					lowest_buf = buf
				end
			end
		end
	end

	if lowest_buf then
		vim.api.nvim_set_current_buf(lowest_buf)
	end
	vim.cmd("bd " .. current_buf)
end

vim.keymap.set("n", "<leader>bc", close_current_buffer, { noremap = true, silent = true, desc = "close current buffer" })
vim.keymap.set("n", "<leader>bn", ":BufferLineCycleNext<CR>", { noremap = true, silent = true, desc = "next buffer" })
vim.keymap.set("n", "<leader>bp", ":BufferLineCyclePrev<CR>", { noremap = true, silent = true, desc = "previous buffer" })
vim.keymap.set("n", "<leader>bb", ":BufferLineCyclePrev<CR>", { noremap = true, silent = true, desc = "buffer before" })

-- Code handling
-- Helper: fold on syntax, go to top and unfold (useful for large JSON files)
local function setfold_and_toggle()
	vim.api.nvim_command("set foldmethod=syntax")
	vim.api.nvim_command("normal gg")
	vim.api.nvim_command("normal zo")
end

vim.keymap.set("n", "<leader>ls", setfold_and_toggle, { noremap = true, silent = true, desc = "fold in method syntax" })

-- Keep things highlighted after shifting with < or > in visual mode
vim.keymap.set("v", "<", "<gv", { noremap = true, silent = true, desc = "keep highlighted after <" })
vim.keymap.set("v", ">", ">gv", { noremap = true, silent = true, desc = "keep highlighted after >" })

-- Info echo: show filetype
vim.keymap.set("n", "<leader>if", ':echo "Filetype: "&ft<CR>', { noremap = true, silent = true, desc = "echo filetype" })

-- vim: ts=2 sts=2 sw=2 et
