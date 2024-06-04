local wezterm = require("wezterm")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.font = wezterm.font("JetBrains Mono", { weight = "DemiBold" })
config.font_size = 18
config.max_fps = 150
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

config.color_scheme = "Dracula (Official)"

config.window_decorations = "RESIZE"

config.default_workspace = "~/Projects"

-- Dracula Color Palette
-- from tmux for coloring tabs
-- to match the tmux colors
local white = "#f8f8f2"
local gray = "#44475a"
local dark_gray = "#282a36"
local light_purple = "#bd93f9"
local dark_purple = "#6272a4"
local cyan = "#8be9fd"
local green = "#50fa7b"
local orange = "#ffb86c"
local red = "#ff5555"
local pink = "#ff79c6"
local yellow = "#f1fa8c"

config.use_fancy_tab_bar = false
config.show_new_tab_button_in_tab_bar = false

-- hides/shows tab bar and sets it at the bottom
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true

-- could we replace other styling info above
-- to a single map?
--config.window_frame = {
--	font = wezterm.font({ family = "JetBrains Mono" }),
--	font_size = 18,
--	active_titlebar_bg = gray,
--	inactive_titlebar_bg = gray,
--}
config.colors = {
	tab_bar = {
		background = gray,
		active_tab = {
			fg_color = white,
			bg_color = dark_purple,
		},
		inactive_tab = {
			bg_color = gray,
			fg_color = white,
		},
	},
}

-- This function returns the suggested title for a tab.
-- It prefers the title that was set via `tab:set_title()`
-- or `wezterm cli set-tab-title`, but falls back to the
-- title of the active pane in that tab.
function tab_title(tab_info)
	local title = tab_info.tab_title
	-- if the tab title is explicitly set, take that
	if title and #title > 0 then
		return title
	end
	-- if not, use active pane's process name
	return wezterm.mux.get_pane(tab_info.active_pane.pane_id):get_foreground_process_info().name
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local title = " " .. tab.tab_index + 1 .. " " .. tab_title(tab) .. " "
	if tab.is_active then
		return {
			{ Background = { Color = dark_purple } },
			{ Text = title },
		}
	end
	return title
end)

-- for wezterm <-> nvim integration
local function is_vim(pane)
	-- this is set by the plugin, and unset on ExitPre in Neovim
	return pane:get_user_vars().IS_NVIM == "true"
end

-- TODO: move to new file
-- custom wezterm / nvim interaction using the
-- the env value for is a pane using vim from the
-- same plugin we are using for pane switching
local function nvim_copy_paste(action)
	return wezterm.action_callback(function(win, pane)
		if is_vim(pane) then
			-- send yank or put to nvim
			-- since it cannot bind to CMD-c or CMD-y
			-- reliably.
			if action == "copy" then
				win:perform_action({
					SendKey = { key = "y" },
				}, pane)
			end
			if action == "paste" then
				win:perform_action({
					SendKey = { key = "p" },
				}, pane)
			end
		else
			-- copy or paste as normal
			-- need to look into PrimarySelection
			if action == "copy" then
				win:perform_action({ CopyTo = { args = { "Clipboard" } } })
			end
			if action == "paste" then
				win:perform_action({ PasteFrom = { args = { "Clipboard" } } })
			end
		end
	end)
end

config.keys = {
	{ mods = "CMD", key = "c", action = nvim_copy_paste("copy") },
	-- CTRL-SHIFT-l activates the debug overlay
	{ key = "L", mods = "CTRL", action = wezterm.action.ShowDebugOverlay },
}

return config
