return {
  'eldritch-theme/eldritch.nvim',
  config = function()
    require('eldritch').setup {
      transparent = true, -- Enable this to disable setting the background color
      terminal_colors = true, -- Configure terminal colors
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        functions = {},
        variables = {},
        sidebars = 'dark', -- Style for sidebars
        floats = 'dark', -- Style for floating windows
      },
      sidebars = { 'qf', 'help' }, -- Set a darker background on sidebar-like windows
      hide_inactive_statusline = false, -- Hide inactive statuslines
      dim_inactive = false, -- Dims inactive windows
      -- on_colors = function(colors)
      --   -- You can customize colors here if needed
      -- end,
      -- on_highlights = function(highlights, colors)
      --   -- You can customize highlights here if needed
      -- end,
    }
    vim.opt.termguicolors = true
    vim.cmd 'syntax enable' -- Enable syntax highlighting priority = 1000,
    -- Set the colorscheme
    vim.cmd.colorscheme 'eldritch'
    -- add transparency to telescope
    vim.cmd [[
      highlight TelescopeNormal ctermbg=NONE guibg=NONE
      highlight TelescopePromptNormal ctermbg=NONE guibg=NONE
      highlight TelescopeResultsNormal ctermbg=NONE guibg=NONE
    ]]
  end,
}
