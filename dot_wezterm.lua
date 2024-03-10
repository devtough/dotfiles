local wezterm = require("wezterm")

local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.font = wezterm.font("MesloLGS NF")
config.font_size = 20
config.max_fps = 150
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }

config.color_scheme = "Kanagawa (Gogh)"

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = true
config.tab_bar_at_bottom = true

config.window_decorations = "RESIZE"

config.default_workspace = "~/Projects"

-- for wezterm <-> nvim integration
local function is_vim(pane)
	-- this is set by the plugin, and unset on ExitPre in Neovim
	return pane:get_user_vars().IS_NVIM == "true"
end

local direction_keys = {
	Left = "h",
	Down = "j",
	Up = "k",
	Right = "l",
	-- reverse lookup
	h = "Left",
	j = "Down",
	k = "Up",
	l = "Right",
}

local function split_nav(resize_or_move, key)
	return {
		key = key,
		mods = resize_or_move == "resize" and "META" or "CTRL",
		action = wezterm.action_callback(function(win, pane)
			if is_vim(pane) then
				-- pass the keys through to vim/nvim
				win:perform_action({
					SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
				}, pane)
			else
				if resize_or_move == "resize" then
					win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
				else
					win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
				end
			end
		end),
	}
end
-- end of wezterm interation

-- custom wezterm / nvim interaction using the
-- the env value for is a pane using vim from the
-- same plugin we are using for pane switching
local function nvim_copy_paste(action)
	return wezterm.action_callback(function(win, pane)
		if is_vim(pane) then
			-- send yank or put to nvim
			-- since it cannot pind to CMD-c or CMD-y
			-- reliably. asdf
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

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{ mods = "CMD", key = "c", action = nvim_copy_paste("copy") },
	-- splitting tabs
	{ mods = "LEADER", key = "s", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ mods = "LEADER", key = "v", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	-- tab navigation between panes

	-- zoom pane to take up tab
	{ mods = "LEADER", key = "z", action = wezterm.action.TogglePaneZoomState },

	-- switching panes
	split_nav("move", "h"),
	split_nav("move", "j"),
	split_nav("move", "k"),
	split_nav("move", "l"),
	-- resize panes
	split_nav("resize", "h"),
	split_nav("resize", "j"),
	split_nav("resize", "k"),
	split_nav("resize", "l"),

	-- not using 'v' here so it doesn't conflict with verticle split
	{
		key = "[",
		mods = "LEADER",
		action = wezterm.action.ActivateCopyMode,
	},

	-- todo reordering panes, and rotating
	--  https://www.florianbellmann.com/blog/switch-from-tmux-to-wezterm
}

return config
