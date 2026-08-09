return {
	"MeanderingProgrammer/render-markdown.nvim",
	-- No nvim-treesitter dependency: parsers + queries are provided by the
	-- nix-injected ~/nvim-treesitter-parsers runtime (see init.lua). Pulling the
	-- lazy nvim-treesitter plugin here merges a *second* copy of queries/ onto
	-- rtp whose version drifts from the loaded parsers — e.g. its python
	-- highlights.scm references the "except*" token that tree-sitter-python
	-- v0.25 no longer exposes, raising "Invalid node type except*" on redraw.
	ft = "markdown",
	opts = {
		heading = {
			enabled = false,
		},
	},
}
