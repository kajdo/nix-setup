# Neovim Hints

## Tree-sitter Parsers

This Neovim setup does not download tree-sitter parsers at runtime.
Parsers are provided by Nix and then loaded by Neovim from a Nix-managed directory.

### Where parsers are defined

The parser packages are listed in:

- `home-manager/modules/dev-tools.nix`

Current setup:

```nix
home.file."nvim-treesitter-parsers".source =
  let
    parsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
      bash diff html json yaml css python javascript typescript markdown_inline query
    ];
  in
  pkgs.symlinkJoin {
    name = "nvim-treesitter-parsers";
    paths = parsers ++ [ pkgs.vimPlugins.nvim-treesitter ];
  };
```

What this does:

1. Takes parser packages from `pkgs.vimPlugins.nvim-treesitter-parsers.<lang>`.
2. Combines them with `pkgs.vimPlugins.nvim-treesitter` using `pkgs.symlinkJoin`.
3. Exposes the result as `~/nvim-treesitter-parsers`.

That joined directory contains:

- `~/nvim-treesitter-parsers/parser/*.so` for parser binaries
- `~/nvim-treesitter-parsers/runtime/queries/*` for tree-sitter highlight queries

### Where Neovim loads them

The loading logic lives in:

- `home-manager/config/nvim/init.lua`

Relevant part:

```lua
local ts_path = vim.env.HOME .. "/nvim-treesitter-parsers"
if vim.fn.isdirectory(ts_path) == 1 then
  vim.opt.rtp:append(ts_path .. "/runtime")
  for _, name in ipairs(vim.fn.readdir(ts_path .. "/parser")) do
    if name:match("%.so$") then
      local lang = name:gsub("%.so$", "")
      vim.treesitter.language.add(lang, { path = ts_path .. "/parser/" .. name })
    end
  end

  vim.treesitter.language.register("bash", { "sh", "zsh" })
end
```

Important detail:

- Queries are under `runtime/queries`, so the runtime path must include `~/nvim-treesitter-parsers/runtime`.
- Parser names do not always match filetypes.

Example:

- filetype: `sh`
- parser: `bash`

That is why this mapping is needed:

```lua
vim.treesitter.language.register("bash", { "sh", "zsh" })
```

## Adding a new language

To add a new tree-sitter language:

1. Add the parser package to the list in `home-manager/modules/dev-tools.nix`.
2. Rebuild with `lull`.
3. If the filetype name differs from the parser name, add a mapping in `home-manager/config/nvim/init.lua` with `vim.treesitter.language.register(...)`.

Example: add `toml`

```nix
parsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
  bash diff html json yaml css python javascript typescript markdown_inline query toml
];
```

Then rebuild:

```bash
lull
```

## How to check if a parser name exists

Parser packages are expected to exist under:

- `pkgs.vimPlugins.nvim-treesitter-parsers.<name>`

If a parser does not exist there, it cannot be added with the current setup.

## Practical rules

1. Prefer Nix-provided parsers over runtime installation.
2. Add the parser package in `dev-tools.nix`.
3. Rebuild so the new `~/.config/nvim` and `~/nvim-treesitter-parsers` are deployed.
4. Add a language mapping only when filetype and parser name differ.

## Notes

- Some parsers are bundled by Neovim 0.12 already, but this setup explicitly manages additional parsers through Nix.
- Python worked without a mapping because the filetype and parser name are both `python`.
- Shell files needed a mapping because the filetype is `sh` while the parser package is `bash`.
