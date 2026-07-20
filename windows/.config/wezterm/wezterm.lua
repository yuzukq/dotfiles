local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- デフォルトシェルを PowerShell に設定
config.default_prog = { "powershell.exe", "-NoLogo" }

-- 見た目
config.color_scheme = "lovelace"
config.font = wezterm.font_with_fallback({
	"Maple Mono NF",
	"Consolas",
})
config.font_size = 16.0

config.window_background_opacity = 0.92
config.win32_system_backdrop = "Acrylic"
-- タイトルバー非表示とリサイズ
config.window_decorations = "RESIZE"
wezterm.on("gui-startup", function(cmd)
	local screen = wezterm.gui.screens().active
	local width, height = 2000, 1000
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
	window:gui_window():set_inner_size(width, height)
	window:gui_window():set_position(
		screen.x + (screen.width - width) / 2,
		screen.y + (screen.height - height) / 2
	)
end)
config.window_padding = {
	left = 20,
	right = 20,
	top = 20,
	bottom = 16,
}

-- タブバー
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true

-- カーソル
config.default_cursor_style = "SteadyBar"
config.cursor_blink_rate = 500

-- スクロールバック
config.scrollback_lines = 5000

-- ベル音を無効化
config.audible_bell = "Disabled"

-- ショートカット追加
config.keys = {
	{ key = "Enter", mods = "ALT", action = wezterm.action.ToggleFullScreen },
	{ key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
	{ key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
	{ key = "+", mods = "CTRL", action = wezterm.action.IncreaseFontSize },
	{ key = "-", mods = "CTRL", action = wezterm.action.DecreaseFontSize },
	{ key = "0", mods = "CTRL", action = wezterm.action.ResetFontSize },
	{
		key = "Enter",
		mods = "CTRL|SHIFT",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
}

return config
