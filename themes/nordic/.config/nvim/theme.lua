-- Symphony by vyrx
-- Theme: Nordic
-- https://github.com/CesarRAN

return {
	{
		"AlexvZyl/nordic.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("nordic").load()
		end,
	},
}
