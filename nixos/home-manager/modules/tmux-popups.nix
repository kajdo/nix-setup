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

  # --- Tools popup menu ---------------------------------------------------
  # Appended after the static tmux.conf (which has no t/r/s binds). r/g/s are
  # selected inside the menu widget, NOT as prefix bindings, so they cannot
  # collide with tmux defaults (e.g. the user's session selector on s).
  toolsMenu = ''
    # === Tools popup menu (prefix + t) ===
    # Reclaim t (clock-mode) for the launcher; preserve clock-mode on T.
    bind-key T clock-mode
    bind-key t display-menu -x C -y C -T "#[bold]Tools" \
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
