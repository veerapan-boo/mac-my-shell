local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false

local color_green = "#027735"
local color_blue = "#2EB2FF"
local bar_bg = "#262626"

config.colors = {
	background = "#111719",
	tab_bar = {
		background = bar_bg,
	},
}

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local index = tab.tab_index + 1
	local process = tab.active_pane.foreground_process_name or ""
	process = process:match("([^/]+)$") or process
	if process == "" then
		process = "shell"
	end

	if tab.is_active then
		return {
			{ Background = { Color = color_green } },
			{ Foreground = { Color = "#ffffff" } },
			{ Text = string.format(" %d: %s ", index, process) },
		}
	else
		return {
			{ Background = { Color = bar_bg } },
			{ Foreground = { Color = color_blue } },
			{ Text = string.format(" [ %d: %s] ", index, process) },
		}
	end
end)

local status_script = wezterm.config_dir .. "/scripts/status.sh"

wezterm.on("update-right-status", function(window, pane)
	local ok, stdout = wezterm.run_child_process({ "/bin/bash", status_script })
	local text = ok and stdout:gsub("%s+$", "") or "status unavailable"

	window:set_right_status(wezterm.format({
		{ Background = { Color = bar_bg } },
		{ Foreground = { Color = color_blue } },
		{ Text = "  " .. text .. "  " },
	}))
end)

return config
