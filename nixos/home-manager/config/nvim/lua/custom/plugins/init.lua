-- Define the function to close the current buffer and switch to the lowest buffer number
local function close_current_buffer()
	-- Get the current buffer number
	local current_buf = vim.api.nvim_get_current_buf()

	-- Get the list of buffers
	local buffers = vim.api.nvim_list_bufs()

	-- Find the buffer with the lowest buffer number that is not the current one and not nvim-tree
	local lowest_buf = nil
	for _, buf in ipairs(buffers) do
		if buf ~= current_buf and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			-- local buf_ft = vim.api.nvim_buf_get_option(buf, 'filetype')
			-- use nvim_get_option_value instead of nvim_buf_get_option
			local buf_ft = vim.api.nvim_get_option_value("filetype", { buf = buf })

			-- local buf_ft = vim.api.vim.api.nvim_get_option(buf, 'filetype')
			if buf_ft ~= "NvimTree" then
				if not lowest_buf or buf < lowest_buf then
					lowest_buf = buf
				end
			end
		end
	end

	-- If a lowest buffer is found, switch to it
	if lowest_buf then
		vim.api.nvim_set_current_buf(lowest_buf)
	end

	-- Close the current buffer
	vim.cmd("bd " .. current_buf)
end

-- Create a Vim command to call the Lua function
vim.api.nvim_create_user_command("CloseCurrentBuffer", close_current_buffer, {})

vim.o.expandtab = true -- Use spaces instead of tabs
vim.o.tabstop = 4 -- Number of spaces that a <Tab> counts for
vim.o.shiftwidth = 4 -- Number of spaces to use for each step of (auto)indent
vim.o.foldenable = false

-- adaptions to handle big json files
vim.api.nvim_create_autocmd("FileType", {
	pattern = "json",
	callback = function()
		require("nvim-treesitter.configs").setup({
			highlight = {
				enable = false, -- Disable Tree-sitter highlighting
			},
		})
	end,
})

-- Define a custom command for sudowrite with error handling
vim.api.nvim_create_user_command("Sudowrite", function()
	local current_file = vim.fn.expand("%") -- Get current file name
	local success = vim.cmd("w !sudo tee " .. current_file .. " > /dev/null")
	if not success then
		print("Failed to save file with sudo.")
	else
		print("File saved with sudo.")
	end
end, {})

-- custom setfold method for json (fold on syntax, go to top of file and toggle fold)
local function setfold_and_toggle()
	vim.api.nvim_command("set foldmethod=syntax")
	vim.api.nvim_command("normal gg")
	vim.api.nvim_command("normal zo")
end

-- Define the key mappings and return them
-- Key mappings for quick access
vim.keymap.set("i", "jk", "<Esc>", { desc = "jk to escape from insert mode" })
vim.keymap.set("i", "kj", "<Esc>", { desc = "kj to escape from insert mode" })
vim.keymap.set("n", "<leader>lc", ":e $MYVIMRC<CR>", { desc = "open configuration file" })
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "toggle explorer" })

-- Buffer handling
vim.keymap.set(
	"n",
	"<leader>bc",
	":CloseCurrentBuffer<CR>",
	{ noremap = true, silent = true, desc = "close current buffer" }
)
vim.keymap.set("n", "<leader>bn", ":BufferLineCycleNext<CR>", { noremap = true, silent = true, desc = "next buffer" })
vim.keymap.set(
	"n",
	"<leader>bp",
	":BufferLineCyclePrev<CR>",
	{ noremap = true, silent = true, desc = "previous buffer" }
)
vim.keymap.set("n", "<leader>bb", ":BufferLineCyclePrev<CR>", { noremap = true, silent = true, desc = "buffer before" })

-- -- openGPT
-- vim.keymap.set("n", "<leader>g", ":ChatGPT<CR>", { noremap = true, silent = true, desc = "openGPT" })
--
-- Code handling
-- leader + l + s = foldinmethod syntax and unfold
vim.keymap.set("n", "<leader>ls", setfold_and_toggle, { noremap = true, silent = true, desc = "fold in method syntax" })
-- keep things highlighted after moving with < or >
vim.keymap.set("v", "<", "<gv", { noremap = true, silent = true, desc = "keep things highlighted after moving with <" })
vim.keymap.set("v", ">", ">gv", { noremap = true, silent = true, desc = "keep things highlighted after moving with >" })

-- info echo
vim.keymap.set(
	"n",
	"<leader>if",
	':echo "Filetype: "&ft<CR>',
	{ noremap = true, silent = true, desc = "info echo filetype" }
)

return {
	-- Your other plugin configurations here
}
