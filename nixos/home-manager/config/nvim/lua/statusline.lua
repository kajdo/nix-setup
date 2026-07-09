-- Custom mini.statusline layout (replaces the verbose default).
--
-- Active window:
--   [MODE]  git  …  filename  …  diagnostics  <icon> filetype  line/total:col
--
-- Compared to the mini.statusline default this drops the noisiest parts:
-- diff stats, search count, the full fileinfo block
-- (encoding / format / size / permissions) and the LSP server name.
local M = {}

function M.setup()
	local statusline = require("mini.statusline")

	statusline.setup({
		content = {
			active = function()
				local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
				local git = statusline.section_git({ trunc_width = 40 })
				local filename = statusline.section_filename({ trunc_width = 140 })
				local diagnostics = statusline.section_diagnostics({ trunc_width = 75 })

				-- Filetype with the same icon nvim-tree uses (via nvim-web-devicons).
				-- Falls back to plain filetype text if devicons is unavailable.
				local filetype = (function()
					local ft = vim.bo.filetype
					if ft == "" then return "" end
					local ok, devicons = pcall(require, "nvim-web-devicons")
					if not ok then return ft end
					local icon = devicons.get_icon_by_filetype(ft)
					if icon == nil then return ft end
					-- icon inherits the section highlight so its background matches the text
					return icon .. " " .. ft
				end)()

				return statusline.combine_groups({
					{ hl = mode_hl, strings = { mode } },
					{ hl = "MiniStatuslineDevinfo", strings = { git } },
					"%<",
					{ hl = "MiniStatuslineFilename", strings = { filename } },
					"%=",
					{ hl = "MiniStatuslineFileinfo", strings = { diagnostics, filetype } },
					-- location: line/total:col (drops the default's line-width field)
					{ hl = mode_hl, strings = { "%l/%L:%v" } },
				})
			end,
			inactive = function()
				return "%#MiniStatuslineInactive#%F%="
			end,
		},
	})
end

return M
