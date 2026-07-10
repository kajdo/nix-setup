# Implementation Plan — Dart Language Support

## Goal
Add Dart language support (LSP + Treesitter) to the existing Neovim configuration, following the established 4-pillar pattern.

## Tasks

1. **Add `dart` package to LSP list in `dev-tools.nix`**
   - File: `home-manager/modules/dev-tools.nix`
   - Changes: Add `dart` to the `# LSPs` comment section in `home.packages` (alphabetical order, between `bash-language-server` and `dockerfile-language-server`)
   - Acceptance: `dart` binary (which provides `dart language-server`) is available in the user environment

2. **Add `dart` treesitter parser in `dev-tools.nix`**
   - File: `home-manager/modules/dev-tools.nix`
   - Changes: Add `dart` to the `parsers` list in the `symlinkJoin` block (alphabetical order, after `css` and before `diff`)
   - Acceptance: `dart.so` parser and `dart` queries are available under `~/nvim-treesitter-parsers/`

3. **Add `dartls` LSP config in `init.lua`**
   - File: `home-manager/config/nvim/init.lua`
   - Changes: Add the following block after the existing `eslint` config and before the `vim.diagnostic.config` line:
     ```lua
     vim.lsp.config('dartls', {
         cmd = { "dart", "language-server", "--protocol=lsp" },
     })
     vim.lsp.enable('dartls')
     ```
   - Acceptance: Opening a `.dart` file triggers the `dartls` language server

4. **Add `"dart"` to FileType autocmd pattern in `custom/plugins/init.lua`**
   - File: `home-manager/config/nvim/lua/custom/plugins/init.lua`
   - Changes: Add `"dart"` to the `pattern` list in the `FileType` autocmd (alphabetical order, after `"css"` and before `"diff"`)
   - Acceptance: Opening a `.dart` file activates treesitter highlighting

## Files to Modify
- `home-manager/modules/dev-tools.nix` — add `dart` package + `nvim-treesitter-parsers.dart` parser
- `home-manager/config/nvim/init.lua` — add `vim.lsp.config('dartls', ...)` + `vim.lsp.enable('dartls')`
- `home-manager/config/nvim/lua/custom/plugins/init.lua` — add `"dart"` to FileType pattern list

## New Files
None.

## Dependencies
- Tasks 1 and 2 are independent of each other but both live in `dev-tools.nix` — can be done in one edit pass.
- Task 3 (LSP config) is independent of Task 4 (treesitter autocmd).
- All tasks are independent; no ordering constraints between files.

## Risks
- **Neovim issue #35775**: Known `textDocument/didChange` issue with Dart 3.9.2+. If the `dart` package resolves to 3.9.2+, LSP incremental sync may break. Mitigation: monitor after rebuild; if affected, consider adding `capabilities` opts to disable incremental sync.
- **No filetype/parser name mapping needed**: Both are `"dart"` (same as Python), so no `vim.treesitter.language.register()` call is required — confirmed by the existing pattern.
- **Parser availability**: `pkgs.vimPlugins.nvim-treesitter-parsers.dart` must exist in the pinned nixpkgs flake input. If it's missing, the rebuild will fail with a clear error. The user would need to update the flake (`nix flake update`) to get a newer nixpkgs revision that includes it.

## Implementation & Review
- [x] Task 1: Added `dart` to `# LSPs` package list in `dev-tools.nix` (between `bash-language-server` and `dockerfile-language-server`)
- [x] Task 2: Added `nvim-treesitter-parsers.dart` to parsers list in `dev-tools.nix` (between `css` and `diff`)
- [x] Task 3: Added `vim.lsp.config('dartls', ...)` + `vim.lsp.enable('dartls')` in `init.lua` (after eslint, before diagnostic config)
- [x] Task 4: Added `"dart"` to FileType autocmd pattern in `custom/plugins/init.lua` (after `"css"`)

**Review notes:**
- All 4 tasks implemented and functionally correct. Two cosmetic ordering deviations:
  - Task 2: `css` was moved to achieve the plan's "after css, before diff" ordering. Parsers list is now partially sorted.
  - Task 4: `"dart"` is after `"css"` ✅ but `"diff"` sits at position 3, so "before diff" isn't satisfied. Autocmd patterns are order-independent — no functional impact.
- Skill findings: 0 critical, 0 warnings, 1 suggestion (parsers list partial sort inconsistency).
- Pre-existing (out of scope): `nixd` is installed as a package but has no `vim.lsp.config('nixd', ...)` in `init.lua`.
