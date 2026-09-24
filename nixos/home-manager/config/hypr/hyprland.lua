-- Hyprland compositor configuration (Lua format, Hyprland >= 0.55)
-- Converted 1:1 from the old hyprland.conf (hyprlang format, removed in 0.57).
-- Docs: https://wiki.hypr.land/Configuring/Core/
-- Old config backup: ~/.config/bak_hypr/hyprland.conf

--------------------------------------------------------------------------------
-- Monitors
-- See https://wiki.hypr.land/Configuring/Core/Monitors/
--------------------------------------------------------------------------------

hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "-1920x0", scale = 1 })

-- needed to reduce the "blackout" when switching mpv to fullscreen
hl.config({ render = { send_content_type = false } })

--------------------------------------------------------------------------------
-- Persistent workspaces
-- See https://wiki.hypr.land/Configuring/Core/Rules/Workspace-Rules/
--------------------------------------------------------------------------------

hl.workspace_rule({ workspace = "1", monitor = "eDP-1", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "9", monitor = "eDP-1", persistent = true })

--------------------------------------------------------------------------------
-- Autostart (old: exec-once)
-- See https://wiki.hypr.land/Configuring/Core/Autostart/
--------------------------------------------------------------------------------

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("waybar")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("wl-clip-persist --clipboard regular")
  -- cycle through workspaces to make the waybar widget show them constantly
  -- (old: hyprctl dispatch workspace 9 && ... && hyprctl dispatch workspace 1)
  for i = 9, 1, -1 do
    hl.dispatch(hl.dsp.focus({ workspace = i }))
  end
end)

--------------------------------------------------------------------------------
-- Variables (old: $variable = value)
--------------------------------------------------------------------------------

local terminal = "kitty"
local fileManager = "thunar"
local menu = "wofi --show drun"
-- for some reason the env=.... is not using path, but this way rofi gets the bash context
local rofi_launch = [[bash -c 'PATH="$PATH:$HOME/.local/bin" ~/.local/bin/rofi_launch.sh']]
local change_wallpaper = "~/git/custom_scripts/hypr_helper/change_wallpaper_swww"
local scratch_script = "~/.local/bin/scratch_kitty"
local exit_command = "~/git/custom_scripts/hypr_helper/exit_wayland"
-- local workspace_init = "bash -c '/home/kajdo/git/custom_scripts/hypr_helper/hypr_init'"
local screenshot = "~/git/custom_scripts/hypr_helper/screenshot"
local scrcpy_remote = "~/git/custom_scripts/hypr_helper/scrcpy_remote"

local mainMod = "SUPER"

--------------------------------------------------------------------------------
-- Environment variables
-- See https://wiki.hypr.land/Configuring/Core/Environment-Variables/
--------------------------------------------------------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct") -- change to qt6ct if you have that

--------------------------------------------------------------------------------
-- Categories
-- See https://wiki.hypr.land/Configuring/Core/Config-Options/
--------------------------------------------------------------------------------

hl.config({
  input = {
    kb_layout = "de",

    follow_mouse = 1,

    touchpad = {
      natural_scroll = true,
    },

    sensitivity = 0, -- -1.0 to 1.0, 0 means no modification.
  },

  general = {
    gaps_in = 5,
    gaps_out = 15,
    border_size = 2,
    col = {
      active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
      inactive_border = "rgba(595959aa)",
    },

    layout = "master",

    -- Please see https://wiki.hypr.land/Configuring/Extra/Tearing/ before you turn this on
    allow_tearing = false,
  },

  cursor = {
    -- cursor doesn't follow active window
    no_warps = true,
    inactive_timeout = 3,
  },

  decoration = {
    rounding = 10,

    blur = {
      enabled = true,
      size = 5,
      passes = 1,
    },

    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    -- NOTE: dwindle.pseudotile was removed in Hyprland 0.55 (it did nothing).
    -- To pseudotile, bind the `pseudo` dispatcher, e.g.: hl.bind("SUPER + P", hl.dsp.window.pseudo())
    preserve_split = true, -- you probably want this
  },

  master = {
    orientation = "left",
  },

  gestures = {
    workspace_swipe_distance = 200,
  },

  misc = {
    force_default_wallpaper = 0, -- 0 or 1 disables the anime mascot wallpapers
  },

  binds = {
    allow_workspace_cycles = true,
  },
})

--------------------------------------------------------------------------------
-- Animations
-- See https://wiki.hypr.land/Configuring/Core/Animations/
--------------------------------------------------------------------------------

-- old: bezier = myBezier, 0.05, 0.9, 0.1, 1.05
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

-- speed up window open and close
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
-- speed up fadein and fadeout for window open/window close
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "default" })
-- speed up workspace switch
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "default" })

--------------------------------------------------------------------------------
-- Gestures
-- See https://wiki.hypr.land/Configuring/Core/Binds/Gestures/
--------------------------------------------------------------------------------

-- Swipe gesture to change workspace
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

--------------------------------------------------------------------------------
-- Per-device config
-- See https://wiki.hypr.land/Configuring/Core/Devices/
--------------------------------------------------------------------------------

hl.device({
  name = "epic-mouse-v1",
  sensitivity = -0.5,
})

--------------------------------------------------------------------------------
-- Window rules
-- See https://wiki.hypr.land/Configuring/Core/Rules/Window-Rules/
--------------------------------------------------------------------------------

-- Ignore maximize requests from all apps. You'll probably like this.
-- (old: windowrule = match:class .*, suppress_event maximize)
hl.window_rule({
  match = { class = ".*" },
  suppress_event = "maximize",
})

-- matplotlib
hl.window_rule({
  match = { class = "^(org.matplotlib.Matplotlib3)$" },
  float = true,
  size = { "(monitor_w*0.7)", "(monitor_h*0.7)" }, -- old: size 70% 70%
})

-- kitty scratchpad: float + center on the ACTIVE monitor. The size comes from
-- kitty itself (scratch_kitty sets initial_window_width=150c, height=45c).
-- NOTE: the old conf's `size 20% 50%` and `move 100%-20% 34` rules never
-- actually applied in the hyprlang era — the historical behavior was always:
-- kitty's natural 150c×45c size, centered by Hyprland's default float placement.
-- Verified pixel-identical on the live compositor (1501×901 @ 210,102).
hl.window_rule({
  match = { class = [[^(.*KittyScratchpad.*)$]] },
  float = true,
  center = true,
})

-- MEGASync (old: size 20% 50%, move 77% -2%)
hl.window_rule({
  match = { class = [[^(.*MEGAsync.*)$]] },
  float = true,
  size = { "(monitor_w*0.2)", "(monitor_h*0.5)" },
  move = { "(monitor_w*0.77)", "(0-monitor_h*0.02)" },
})

-- calculator / tauri test apps
hl.window_rule({ match = { class = "^(org.gnome.Calculator)$" }, float = true })
hl.window_rule({ match = { class = ".*tauri-test.*" }, float = true })

--------------------------------------------------------------------------------
-- ██╗  ██╗███████╗██╗   ██╗    ██████╗ ██╗███╗   ██╗██████╗ ██╗███╗   ██╗ ██████╗ ███████╗
-- ██║ ██╔╝██╔════╝╚██╗ ██╔╝    ██╔══██╗██║████╗  ██║██╔══██╗██║████╗  ██║██╔════╝ ██╔════╝
-- █████╔╝ █████╗   ╚████╔╝     ██████╔╝██║██╔██╗ ██║██║  ██║██║██╔██╗ ██║██║  ███╗███████╗
-- ██╔═██╗ ██╔══╝    ╚██╔╝      ██╔══██╗██║██║╚██╗██║██║  ██║██║██║╚██╗██║██║   ██║╚════██║
-- ██║  ██╗███████╗   ██║       ██████╔╝██║██║ ╚████║██████╔╝██║██║ ╚████║╚██████╔╝███████║
-- ╚═╝  ╚═╝╚══════╝   ╚═╝       ╚═════╝ ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
-- Key Bindings
-- See https://wiki.hypr.land/Configuring/Core/Binds/
--------------------------------------------------------------------------------

-- Terminals -------------------------------------------------------------------

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind("ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("/etc/profiles/per-user/kajdo/bin/kitty"))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd("/etc/profiles/per-user/kajdo/bin/kitty"))
hl.bind("F12", hl.dsp.exec_cmd("/etc/profiles/per-user/kajdo/bin/kitty"))
hl.bind("ALT + SHIFT + T", hl.dsp.exec_cmd(scratch_script))

-- Touchpad toggle -------------------------------------------------------------
-- NOTE: "hyprctl keyword" no longer exists in the Lua config era; hl.device()
-- is the runtime equivalent of the old `keyword device[...]:enabled` toggles.

hl.bind("ALT + SHIFT + M", function()
  hl.device({ name = "synaptics-tm3072-003", enabled = false })
end)
hl.bind("ALT + SHIFT + N", function()
  hl.device({ name = "synaptics-tm3072-003", enabled = true })
end)

-- Bluetooth headset: toggle call mode (HSP/HFP) <-> music (A2DP) --------------

hl.bind("F9", hl.dsp.exec_cmd("~/.local/bin/rofi_call_prep.sh toggle"))

-- Debug -----------------------------------------------------------------------

hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("echo $PATH > ~/hypr_path_debug.txt"))

-- Close / exit ----------------------------------------------------------------
-- (old: killactive = forceful kill of the active window)

hl.bind(mainMod .. " + Q", hl.dsp.window.kill())
hl.bind("ALT + Q", hl.dsp.window.kill())

hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd(exit_command))
hl.bind("ALT + SHIFT + Q", hl.dsp.exec_cmd(exit_command))

-- Screenshots -----------------------------------------------------------------

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot))
hl.bind("ALT + SHIFT + S", hl.dsp.exec_cmd(screenshot))

-- File manager ----------------------------------------------------------------

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind("ALT + E", hl.dsp.exec_cmd(fileManager))

-- Floating --------------------------------------------------------------------

hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind("ALT + V", hl.dsp.window.float())

-- Launchers -------------------------------------------------------------------

hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(rofi_launch))
hl.bind("ALT + R", hl.dsp.exec_cmd(rofi_launch))

-- Wallpaper -------------------------------------------------------------------

hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd(change_wallpaper))
hl.bind("ALT + SHIFT + W", hl.dsp.exec_cmd(change_wallpaper))

-- Layout: cycle focus / resize -------------------------------------------------
-- (old: layoutmsg cyclenext / cycleprev, resizeactive)

hl.bind(mainMod .. " + J", hl.dsp.layout("cyclenext"))
hl.bind("ALT + J", hl.dsp.layout("cyclenext"))

hl.bind(mainMod .. " + K", hl.dsp.layout("cycleprev"))
hl.bind("ALT + K", hl.dsp.layout("cycleprev"))

hl.bind("SUPER + H", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
hl.bind("ALT + H", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))

hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("ALT + L", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))

-- Fullscreen ------------------------------------------------------------------
-- (old: fullscreen = real fullscreen, fullscreen,1 = maximize)

hl.bind("ALT + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("ALT + M", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Move windows directionally ---------------------------------------------------

hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

hl.bind("ALT + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("ALT + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind("ALT + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("ALT + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- Switch workspaces -------------------------------------------------------------
-- with mainMod + [0-9] ...

for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind("ALT + " .. key, hl.dsp.focus({ workspace = i })) -- to make it work on android (sunshine)
end

hl.bind(mainMod .. " + I", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + U", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("ALT + I", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("ALT + U", hl.dsp.focus({ workspace = "r-1" }))

-- jumping between monitors

hl.bind("ALT + comma", hl.dsp.focus({ monitor = "+1" }))
hl.bind("ALT + SHIFT + comma", hl.dsp.window.move({ monitor = "+1" }))

-- (allow_workspace_cycles is set in the binds category above)

hl.bind(mainMod .. " + Escape", hl.dsp.focus({ workspace = "previous" }))
hl.bind("ALT + Escape", hl.dsp.focus({ workspace = "previous" }))

-- Move active window to a workspace with mainMod + SHIFT + [0-9] ----------------
-- (and the ALT + SHIFT variant)

for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
  hl.bind("ALT + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
end

-- Special workspace (scratchpad) ------------------------------------------------

hl.bind("ALT + B", hl.dsp.workspace.toggle_special("magic"))
hl.bind("ALT + SHIFT + B", hl.dsp.window.move({ workspace = "special:magic", follow = true }))

-- Scroll through existing workspaces with mainMod + scroll ----------------------

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "r-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging -----------------------

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("ALT + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- vim: ts=2 sts=2 sw=2 et
