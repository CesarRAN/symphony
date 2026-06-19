-- Symphony by vyrx
-- Theme: Kanagawa
-- https://github.com/CesarRAN

return {
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				theme = "wave",
			})
			vim.cmd.colorscheme("kanagawa")
		end,
	},
}
