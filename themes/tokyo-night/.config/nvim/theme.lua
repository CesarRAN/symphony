-- Symphony by vyrx
-- Theme: Tokyo Night
-- https://github.com/CesarRAN

return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("tokyonight-night")
		end,
	},
}
