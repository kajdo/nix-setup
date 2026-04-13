Plan written to `.pi/plans/add-dart-language-support.md`.

**Summary of 4 changes across 3 files:**

| # | File | Change |
|---|------|--------|
| 1 | `dev-tools.nix` | Add `dart` to `# LSPs` package list |
| 2 | `dev-tools.nix` | Add `nvim-treesitter-parsers.dart` to parsers list |
| 3 | `init.lua` | Add `vim.lsp.config('dartls', { cmd = { "dart", "language-server", "--protocol=lsp" } })` + `vim.lsp.enable('dartls')` |
| 4 | `custom/plugins/init.lua` | Add `"dart"` to the FileType autocmd pattern list |

All changes are minimal, follow existing patterns exactly, and are independent of each other. The key risk is Neovim issue #35775 with Dart 3.9.2+ incremental sync — worth monitoring after the rebuild.