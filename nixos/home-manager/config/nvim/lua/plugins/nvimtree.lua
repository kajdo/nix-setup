return {
  'nvim-tree/nvim-tree.lua',
  -- opts = {},
  opts = {
    on_attach = function(bufnr)
      local api = require 'nvim-tree.api'
      local function opts(desc)
        return { desc = 'nvim-tree: ' .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      -- Default mappings are not enabled. You need to define your own.
      vim.keymap.set('n', 'l', api.node.open.edit, opts 'Edit')
      vim.keymap.set('n', 'h', api.node.navigate.parent_close, opts 'Close Node')
      vim.keymap.set('n', 'v', api.node.open.vertical, opts 'Open: Vertical Split')
    end,
    git = {
      enable = false,
    },
    view = {
      width = 30,
      side = 'left',
    },
    renderer = {
      highlight_opened_files = 'all',
    },
  },
}
