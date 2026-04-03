return {
  -- "pablopunk/pi.nvim",
  dir = "/home/kajdo/git/pi.nvim",
  config = function()
    require("pi").setup()

    vim.keymap.set("n", "<leader>ai", ":PiAsk<CR>", { desc = "Ask pi" })
    vim.keymap.set("v", "<leader>ai", ":PiAskSelection<CR>", { desc = "Ask pi (selection)" })
  end,
}
