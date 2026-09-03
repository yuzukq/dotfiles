local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- デフォルトシェルの設定
-- oh-my-posh 等のプロファイル設定は Documents\PowerShell\ 側 (pwsh用) にあるので注意
config.default_prog = { "pwsh.exe", "-NoLogo" }

-- 見た目
config.color_scheme = "lovelace"
config.font = wezterm.font_with_fallback({
	"Maple Mono NF",
	"Consolas",
})
config.font_size = 16.0

config.window_background_opacity = 0.92
config.win32_system_backdrop = "Acrylic"

-- タブバー
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

-- タブが1つでも常に表示する
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false

-- タブバー配色
local miku = {
	black = "#252729",
	gray = "#bec8d1",
	blue = "#86cecb",
	green = "#22949a",
	pink = "#e12885",
}
config.colors = {
	tab_bar = {
		background = miku.black,
		active_tab = {
			bg_color = miku.pink,
			fg_color = miku.black,
			intensity = "Bold",
		},
		inactive_tab = {
			bg_color = miku.black,
			fg_color = miku.gray,
		},
		inactive_tab_hover = {
			bg_color = miku.green,
			fg_color = miku.black,
		},
		new_tab = {
			bg_color = miku.black,
			fg_color = miku.blue,
		},
		new_tab_hover = {
			bg_color = miku.blue,
			fg_color = miku.black,
		},
	},
}

-- 解像度を加味したセンタリング
local WINDOW_SIZE_RATIO = { width = 0.65, height = 0.7 }
wezterm.on("gui-startup", function(cmd)
	local screen = wezterm.gui.screens().active
	local width = math.floor(screen.width * WINDOW_SIZE_RATIO.width)
	local height = math.floor(screen.height * WINDOW_SIZE_RATIO.height)
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
