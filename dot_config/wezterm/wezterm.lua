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
}

return config
