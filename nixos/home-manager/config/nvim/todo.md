# TODOs to make it more like lvim

## fix kickstarter-config
- [x] lua lsp needs way to much memory (fix was to disable lazydev, and add globals + workspace)

## Explorer
- [x] include nvim-tree
    - [x] Toggle
    - [x] make key bindings work like in lvim (l to open)

## key bindings
- [x] add init.lua with custom key bindings
    - [x] toggle nvim-tree
    - [x] `jk` in insert view to `<Esc>`

## telescope
- [x] make ctrl+q close telescope 

## tabline/bufferline setup
- [x] make tabline work

## Lualine
- [x] include lualine instead of mini statusline
- [x] make the status line work (currently each buffer have one)

## Bufferline
- [x] make bufferline work
- [x] make sensible bufferline key bindings

## add bling
- [x] add noice for fancyfication

## add missing functions
- [x] add close buffer function

## include AI code completion
- [x] include AI code completion (codeium)

## fix json formatting
- [x] disable treesitter for json (long lines json break the editor)
- [x] define biome as json formatter
- [x] check why tabstop uses so many characers in nvim
- [x] create special fold function and assign a keybinding (foldmethod=syntax, gg, zo)

## cleanup which-key
