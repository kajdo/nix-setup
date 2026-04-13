# Progress — Add Dart Language Support

## Implementation
- [x] Task 1: Added `dart` to `# LSPs` package list in `dev-tools.nix` (between `bash-language-server` and `dockerfile-language-server`)
- [x] Task 2: Added `nvim-treesitter-parsers.dart` to parsers list in `dev-tools.nix` (between `css` and `diff`)
- [x] Task 3: Added `vim.lsp.config('dartls', ...)` + `vim.lsp.enable('dartls')` in `init.lua` (after eslint, before diagnostic config)
- [x] Task 4: Added `"dart"` to FileType autocmd pattern in `custom/plugins/init.lua` (after `"css"`)

## Review
- **Plan alignment:** All 4 tasks are implemented and functionally correct. Two cosmetic ordering deviations:
  - Task 2: Worker also moved `css` from its original position to achieve the plan's "after css, before diff" ordering. The parsers list is now partially sorted (first 4 entries alphabetical, rest unsorted).
  - Task 4: `"dart"` is after `"css"` ✅ but `"diff"` is at position 3 in the pattern list, so the "before diff" part isn't satisfied. Autocmd patterns are order-independent so this doesn't affect functionality.
- **Skill findings summary:** 0 critical, 0 warnings, 1 suggestion (parsers list partial sort inconsistency)
- **Fixed:** Nothing to fix — implementation is functionally correct
- **Note:** Pre-existing issue observed: `nixd` is installed as a package but has no `vim.lsp.config('nixd', ...)` in `init.lua` (out of scope for this plan)
