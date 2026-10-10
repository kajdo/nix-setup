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
-- for some reason the env=.... is not using path, but this way rofi gets the bash context
local rofi_launch = [[bash -c 'PATH="$PATH:$HOME/.local/bin" ~/.local/bin/rofi_launch.sh']]
local bookmarks = "~/git/bofi/bin/bofi"
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

-- Thunar file manager: always open floating, never tiled
hl.window_rule({
  match = { class = "^(thunar)$" },
  float = true,
  size = { "(monitor_w*0.65)", "(monitor_h*0.7)" },
})

-- Bitwarden browser-extension window (login prompt, Ctrl+Shift+L):
-- Chromium extension windows get class "chrome-<ext-id>-Default". The
-- ext-id is key-derived (stable per install source) but differs between
-- sources. Static rule for the current install + a generic "^chrome%-"
-- branch in the window.open listener below (initial_title matching is
-- NOT available on 0.56.x -- verified -- so the listener is the generic
-- fallback for any extension id).
hl.window_rule({
  match = { class = "^chrome-mnohbhncmaenaaigligdegaipglbnppp" },
  float = true,
  center = true,
})

-- Citrix virtual apps (Wfica, e.g. remote Outlook): tiled, but assigned to
-- workspace 4. Title varies by app, so match on class only.
-- Use workspace = "4 silent" to avoid focusing ws 4 when the app opens.
hl.window_rule({
  match = { class = "^(Wfica)$" },
  workspace = "4",
})

-- Citrix "I'm working..." splash popup (class + title): floating.
-- MUST come after the rule above: later rules take precedence, so
-- workspace = "unset" keeps the popup on the current workspace
-- instead of dragging it to workspace 4.
hl.window_rule({
  match = { class = "^(Wfica)$", title = "^(Citrix Workspace)$" },
  float = true,
  workspace = "unset",
})

-- Helium browser popups (e.g. PayPal checkout): float, while the main
-- browser window stays tiled.
--
-- Why an event listener instead of a static window_rule with
-- initial_title = "^about:blank"? Static rules are evaluated when the
-- window is CREATED, and at that moment chromium popups still have an
-- EMPTY title -- "about:blank - Helium" is only set a few events later
-- (still pre-map), so title-based static matching never fires (verified
-- live with an instrumented config on Hyprland 0.56.2). The window.title
-- event also fires PRE-map, so dispatching there targets a not-yet-mapped
-- window and is silently dropped. The window.open event fires at map time
-- with class + title fully populated; dispatching float there applies in
-- the same frame (no tile->float flicker; verified). Main windows never
-- start with about:blank, so they stay tiled.
-- Generic popup geometry: fixed 600x400 px, centered on the popup's
-- monitor. Dispatchers take plain pixel coords only (no monitor_w math).
-- NOTE: keep exactly ONE hl.on() registration per event name -- a second
-- registration for the same event silently breaks the callback (0.56.x).
hl.on("window.open", function(w)
  if w == nil then return end
  if w.class == "helium" and w.title and w.title:match("^about:blank") then
    hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
    hl.dispatch(hl.dsp.window.resize({ x = 600, y = 400, relative = false, window = w }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
  elseif w.class and w.class:match("^chrome%-") then
    -- any chromium extension window (class "chrome-<ext-id>-Default"),
    -- e.g. Bitwarden login: float + fixed 600x400 + center (their own
    -- requested size is unreliable, chromium remembers ad-hoc sizes)
    hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
    hl.dispatch(hl.dsp.window.resize({ x = 600, y = 400, relative = false, window = w }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
  end
end)

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

hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd(bookmarks))
hl.bind("ALT + SHIFT + R", hl.dsp.exec_cmd(bookmarks))
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

-- Switch workspaces (dwm-style) -------------------------------------------------
-- Global helpers (NOT local: the test suite drives them via `hyprctl eval`
-- and real binds) — see tests/hypr-workspaces/ (BASELINE_BOOT7).

-- S2+S5: switch to ws n and warp the cursor to the target monitor's center
-- BEFORE focusing, so keyboard focus follows the workspace regardless of
-- where the cursor currently is (fixes cross-monitor focus theft).
function goto_workspace(n)
  local ws  = hl.get_workspace(n)
  local mon = ws and ws.monitor
  if mon then
    local at = hl.get_monitor_at_cursor()
    if not at or at.name ~= mon.name then
      hl.dispatch(hl.dsp.cursor.move({
        x = mon.x + mon.width / 2,
        y = mon.y + mon.height / 2,
      }))
    end
  end
  -- ws + monitor switch (CA::changeWorkspace: does NOT move keyboard focus)
  hl.dispatch(hl.dsp.focus({ workspace = n }))
  -- hand keyboard focus to the target ws's most-recently-focused window:
  -- changeWorkspace alone leaves the previously-focused window focused (the
  -- user-reported theft: alt+N switches ws but the old window keeps keyboard;
  -- measured FAIL in AFTER-diagnostic T4a — scratchpad kept focus cross-mon)
  local best, bestid = nil, math.huge
  for _, w in ipairs(hl.get_windows()) do
    if w.workspace and w.workspace.id == n and w.focus_history_id >= 0 and w.focus_history_id < bestid then
      best, bestid = w, w.focus_history_id
    end
  end
  if best then
    hl.dispatch(hl.dsp.focus({ window = "address:" .. best.address }))
  end
end

-- S4: global arithmetic cycling over the fixed set 1..9 with wraparound
-- (9 -> +1 wraps to 1, 1 -> -1 wraps to 9). Never leaves the 1..9 range.
function cycle_workspace(delta)
  local aws = hl.get_active_workspace()
  local id  = aws and aws.id or 1
  goto_workspace(((id - 1 + delta) % 9) + 1)
end

-- S6: monitor monitor delta away from the focused one (nil if <2 monitors)
function monitor_by_delta(delta)
  local mons = hl.get_monitors()
  if #mons < 2 then return nil end
  local cur = hl.get_active_workspace().monitor
  local ci  = 1
  for i, m in ipairs(mons) do
    if m.name == cur.name then ci = i end
  end
  return mons[((ci - 1 + delta) % #mons) + 1]
end

-- S6: jump to the other monitor's ACTIVE workspace (dwm focusmon semantics:
-- the target monitor's own state decides — ws1 or ws9 on eDP, whichever it
-- shows right now). Reuses the full goto discipline (warp + switch + focus
-- last window). Plain focus({monitor="+1"}) left the pointer parked on the
-- source monitor under a hovered window (no_warps guts its warpCursor),
-- and follow_mouse re-asserted it as active: waybar flipped back, spawns
-- landed on the OLD ws (split-brain).
function goto_monitor(delta)
  local target = monitor_by_delta(delta)
  if target then goto_workspace(target.active_workspace.id) end
end

-- S6: "previous" workspace via Hyprland's own history tracker — same source
-- as the old focus({workspace="previous"}). goto_workspace warps only when
-- the previous ws lives on the OTHER monitor (same-display history = no
-- cursor jump). Guard preserves old behavior: prev == current is a no-op.
function goto_previous_workspace()
  local prev = hl.get_last_workspace()
  if prev and prev.id ~= hl.get_active_workspace().id then
    goto_workspace(prev.id)
  end
end

-- S6: send-and-follow monitor move. follow=true alone would split-brain
-- (its warpCursor() is neutered by no_warps) — pre-warp the cursor to the
-- target monitor first, then the follow path (move + view + focus) is
-- coherent.
function move_window_to_monitor(delta)
  if not hl.get_active_window() then return end
  local target = monitor_by_delta(delta)
  if not target then return end
  hl.dispatch(hl.dsp.cursor.move({
    x = target.x + target.width / 2,
    y = target.y + target.height / 2,
  }))
  hl.dispatch(hl.dsp.window.move({ monitor = target.name, follow = true }))
end

-- Direct switch with mainMod/ALT + [1-9] (key 0 -> ws10 dropped: the set is
-- exactly 1..9, S3; old binds used plain focus() and suffered focus theft)

for i = 1, 9 do
  hl.bind(mainMod .. " + " .. i, function() goto_workspace(i) end)
  hl.bind("ALT + " .. i, function() goto_workspace(i) end) -- to make it work on android (sunshine)
end

-- Arithmetic cycling with mainMod/ALT + I/U (old: r+1/r-1 — no wraparound:
-- +1 from ws9 created ws10, -1 from ws1 was a no-op)

hl.bind(mainMod .. " + I", function() cycle_workspace(1) end)
hl.bind(mainMod .. " + U", function() cycle_workspace(-1) end)
hl.bind("ALT + I", function() cycle_workspace(1) end)
hl.bind("ALT + U", function() cycle_workspace(-1) end)

-- jumping between monitors

hl.bind("ALT + comma", function() goto_monitor(1) end)
hl.bind("ALT + SHIFT + comma", function() move_window_to_monitor(1) end)

-- (allow_workspace_cycles is set in the binds category above)

hl.bind(mainMod .. " + Escape", function() goto_previous_workspace() end)
hl.bind("ALT + Escape", function() goto_previous_workspace() end)

-- Move active window to a workspace with mainMod + SHIFT + [1-9] ----------------
-- (and the ALT + SHIFT variant; key 0 dropped with the switch binds — S3:
-- the workspace set is exactly 1..9. follow=true theft is a flagged
-- follow-up, out of scope here)

for i = 1, 9 do
  hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
  hl.bind("ALT + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
end

-- Special workspace (scratchpad) ------------------------------------------------

hl.bind("ALT + B", hl.dsp.workspace.toggle_special("magic"))
hl.bind("ALT + SHIFT + B", hl.dsp.window.move({ workspace = "special:magic", follow = true }))

-- Scroll through workspaces with mainMod + scroll (same fixed-set cycle) --------

hl.bind(mainMod .. " + mouse_down", function() cycle_workspace(1) end)
hl.bind(mainMod .. " + mouse_up", function() cycle_workspace(-1) end)

-- Move/resize windows with mainMod + LMB/RMB and dragging -----------------------

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("ALT + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- vim: ts=2 sts=2 sw=2 et
