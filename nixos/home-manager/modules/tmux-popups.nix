{ config, pkgs, lib, ... }:

let
  # --- Tool launchers -----------------------------------------------------
  # Each is a self-contained shell app with its own PATH closure (runtimeInputs),
  # so the tool and its helpers (e.g. git) resolve even when tmux spawns the
  # popup with a minimal environment. The tmux menu references each by its
  # absolute store path, avoiding any reliance on the popup shell's PATH.
  popLazygit = pkgs.writeShellApplication {
    name = "tmux-popup-lazygit";
    runtimeInputs = [ pkgs.git pkgs.lazygit ];
    text = ''
      # Land at the repo root when inside a repo, else stay in cwd.
      cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      exec lazygit "$@"
    '';
  };

  popPosting = pkgs.writeShellApplication {
    name = "tmux-popup-posting";
    runtimeInputs = [ pkgs.posting pkgs.fd ];
    text = ''
      # Use a project-local collection if one is detectable, else posting's
      # global default collection.
      collection=""
      for cand in .posting posting requests; do
        if [ -d "$cand" ]; then collection="$cand"; break; fi
      done
      if [ -z "$collection" ] && fd -g '*.posting.yaml' --max-results 1 >/dev/null 2>&1; then
        collection="."
      fi
      if [ -n "$collection" ]; then
        exec posting --collection "$collection"
      fi
      exec posting
    '';
  };

  # harlequin wrapper that silences click's duplicate-parameter UserWarnings.
  # nixpkgs relaxes harlequin's click==8.1.8 pin (pythonRelaxDeps), letting
  # click 8.2+ in, which warns because the bundled adapters reuse short flags
  # (-l/-p/-u). Cosmetic only; harlequin works fine. Wrapping here (instead of
  # the real package) covers BOTH direct `harlequin` and the popup below.
  harlequinWrapped = pkgs.writeShellApplication {
    name = "harlequin";
    runtimeInputs = [ pkgs.harlequin ];
    text = ''
      export PYTHONWARNINGS="ignore::UserWarning"
      exec harlequin "$@"
    '';
  };

  popHarlequin = pkgs.writeShellApplication {
    name = "tmux-popup-harlequin";
    runtimeInputs = [ harlequinWrapped ];
    text = ''
      # harlequin auto-discovers .harlequin.toml / [tool.harlequin] from cwd.
      exec harlequin "$@"
    '';
  };

  # --- Switch-or-create helper (KEEP mode) --------------------------------
  # Focus an already-open named window for this tool+project (warm -> no cold
  # start), else create one that runs the tool and auto-closes on tool exit.
  # Invoked by the prefix-t menu via `run-shell`. Needs tmux (to issue control
  # commands) and git (to resolve the repo toplevel for a stable name).
  tmuxToolWin = pkgs.writeShellApplication {
    name = "tmux-tool-window";
    runtimeInputs = [ pkgs.git pkgs.tmux ];
    text = ''
      tool="$1"
      launcher="$2"
      # The helper's own cwd is the tmux server's, so ask tmux for the cwd of
      # the pane that opened the menu (the current client's active pane).
      cwd="$(tmux display-message -p '#{pane_current_path}')"
      # Stable project base: repo toplevel inside a repo (matches the lazygit
      # launcher's own cd-to-toplevel), else the pane cwd. Keeps one window per
      # repo/tool regardless of which subdir we trigger from.
      toplevel="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
      base="$(basename "''${toplevel:-$cwd}")"
      name="$tool-$base"
      if tmux select-window -t "$name" 2>/dev/null; then
        :  # warm window already open -> just focus (does NOT re-cd)
      else
        wid="$(tmux new-window -P -F '#{window_id}' -c "$cwd" -n "$name" "$launcher")"
        # automatic-rename is ON by default and would rename the window to the
        # tool's basename (e.g. "lazygit"), breaking idempotent re-focus. Disable
        # it on THIS window so "<tool>-<base>" persists.
        tmux setw -t "$wid" automatic-rename off
      fi
    '';
  };

  # --- Tools menus (prefix + t / prefix + T) ------------------------------
  # t = KEEP mode: open or switch-to a persistent named window (warm -> no
  #     cold start). Selections call the switch-or-create helper via run-shell.
  # T = POPUP mode: ephemeral display-popup (previous behavior), killed on close.
  # Clock-mode (formerly on T) is intentionally dropped.
  # In-menu keys are lowercase r/g/s in BOTH menus (mode is decided by the entry
  # point t vs T, not by letter case) -> no collision with tmux defaults
  # (e.g. the user's session selector on prefix-s stays untouched).
  toolsMenu = ''
    # === Tools menu — KEEP mode (prefix + t) ===
    bind-key t display-menu -x C -y C -T "#[bold]Tools (keep)" \
      "REST   posting"   r  "run-shell '${tmuxToolWin}/bin/tmux-tool-window posting ${popPosting}/bin/tmux-popup-posting'" \
      "Git    lazygit"   g  "run-shell '${tmuxToolWin}/bin/tmux-tool-window lazygit ${popLazygit}/bin/tmux-popup-lazygit'" \
      "SQL    harlequin" s  "run-shell '${tmuxToolWin}/bin/tmux-tool-window harlequin ${popHarlequin}/bin/tmux-popup-harlequin'"

    # === Tools menu — POPUP mode (prefix + T) ===
    bind-key T display-menu -x C -y C -T "#[bold]Tools (popup)" \
      "REST   posting"   r  "display-popup -d '#{pane_current_path}' -w 80% -h 80% -E ${popPosting}/bin/tmux-popup-posting" \
      "Git    lazygit"   g  "display-popup -d '#{pane_current_path}' -w 80% -h 80% -E ${popLazygit}/bin/tmux-popup-lazygit" \
      "SQL    harlequin" s  "display-popup -d '#{pane_current_path}' -w 80% -h 80% -E ${popHarlequin}/bin/tmux-popup-harlequin"
  '';
in
{
  # --- Packages -----------------------------------------------------------
  home.packages = with pkgs; [
    lazygit
    posting
  ] ++ [ harlequinWrapped ];

  # --- Append the Tools menu to the existing tmux config ------------------
  # dev-tools.nix already sets programs.tmux.extraConfig to the static
  # tmux.conf; mkAfter (works because extraConfig is types.lines) appends our
  # menu after it. tmux reads config top-to-bottom, so bind-key t overrides
  # the default clock-mode on t.
  programs.tmux.extraConfig = lib.mkAfter toolsMenu;
}
