local wezterm = require("wezterm")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.font = wezterm.font("MesloLGS NF")
config.font_size = 20
config.max_fps = 150
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

config.color_scheme = "Dracula (base16)"

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = true
config.tab_bar_at_bottom = true

config.window_decorations = "RESIZE"

config.default_workspace = "~/Projects"

return config
