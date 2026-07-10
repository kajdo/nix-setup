# Implementation Plan — tmux Tools Popup

## Goal
Add a single tmux leader key (`prefix + t`) that opens a centered **Tools** menu; choosing `r`/`g`/`s` launches **posting** / **lazygit** / **harlequin** in a `display-popup` rooted at the current pane's working directory, so the user can quickly fire a REST call / git commit / SQL query and leave (`q`) without losing focus.

## Locked decisions (do not re-litigate)
1. **Branch:** `feat/tmux-tool-popups` (throwaway-friendly).
2. **Launcher key:** `prefix + t`. Reclaim `t` (tmux default = `clock-mode`); remap `clock-mode` → `prefix + T`.
3. **In-menu selectors** `r`/`g`/`s` are interpreted by the menu widget, **not** the prefix table → no collision with tmux defaults (notably the user's `prefix + s` = `choose-tree -Zs` session selector stays untouched).
4. **Posting collection:** auto-detect a project-local collection (dir `.posting`/`posting`/`requests`, or a cwd containing `*.posting.yaml`); use `posting --collection <that>` if found, else plain `posting` (global default).
5. **lazygit:** `cd` to git repo toplevel (`git rev-parse --show-toplevel`, fallback cwd) then launch.
6. **harlequin:** plain `harlequin` (auto-discovers `.harlequin.toml` / `[tool.harlequin]` from cwd).

## Verified facts (treat as authoritative)
- tmux **3.7b**, prefix `C-b`. `tmux list-keys -T prefix` confirms: `t`→`clock-mode`, `r`→`refresh-client`, `s`→`choose-tree -Zs` (user's session selector — must NOT change), `p`→`paste-buffer`. Free lowercase prefix keys: `a b e g v y`.
- `programs.tmux.extraConfig` is **`types.lines`** (checked in the home-manager module `tmux.nix:206`; final config assembled with `mkBefore`/`mkAfter` at lines 360-361). Therefore `lib.mkAfter` **merges** our menu after the existing static config instead of conflicting. This is what lets `dev-tools.nix` stay untouched.
- All three tools exist in nixpkgs `unstable`: `posting` (v2.10.0), `lazygit`, `harlequin` (v2.5.2 — already bundles sqlite + duckdb + postgres + bigquery adapters; **no extra adapter packages needed**).
- `tmux display-popup -d "#{pane_current_path}" -w 80% -h 80% -E "<cmd>"` sets cwd to the pane's path and auto-closes on exit. `display-menu -x C -y C` is centered.

## Tasks

### 1. Create the feature branch
- **Action:** `git checkout -b feat/tmux-tool-popups` from the repo root (`/home/kajdo/git/nix-setup`), currently on `main` (clean tree).
- **Acceptance:** `git branch --show-current` prints `feat/tmux-tool-popups`.

### 2. Create new module `home-manager/modules/tmux-popups.nix`
- **File:** `nixos/home-manager/modules/tmux-popups.nix` (new)
- **Header:** `{ config, pkgs, lib, ... }:`
- **Contents** (paste verbatim, then review comments):
  ```nix
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

    popHarlequin = pkgs.writeShellApplication {
      name = "tmux-popup-harlequin";
      runtimeInputs = [ pkgs.harlequin ];
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
      harlequin
    ];

    # --- Append the Tools menu to the existing tmux config ------------------
    # dev-tools.nix already sets programs.tmux.extraConfig to the static
    # tmux.conf; mkAfter (works because extraConfig is types.lines) appends our
    # menu after it. tmux reads config top-to-bottom, so bind-key t overrides
    # the default clock-mode on t.
    programs.tmux.extraConfig = lib.mkAfter toolsMenu;
  }
  ```
- **Acceptance:** File exists, parses (no `nix` command run by us — see Validation). Nix `''...''` rules respected (see "Critical Nix string-interpolation notes" below).

### 3. Import the new module in `home.nix`
- **File:** `nixos/home.nix`
- **Change:** add one line to the `imports` list. Place it directly after `./home-manager/modules/dev-tools.nix` for thematic grouping with tmux (any position is functionally equivalent).
- **Before:**
  ```nix
  imports = [
    ./home-manager/modules/cli-utils.nix
    ./home-manager/modules/dev-tools.nix
    ./home-manager/modules/gtk-theming.nix
  ```
- **After:**
  ```nix
  imports = [
    ./home-manager/modules/cli-utils.nix
    ./home-manager/modules/dev-tools.nix
    ./home-manager/modules/tmux-popups.nix
    ./home-manager/modules/gtk-theming.nix
  ```
- **Acceptance:** `./home-manager/modules/tmux-popups.nix` appears once in the imports list.

### 4. (No other edits)
- Do **not** modify `home-manager/modules/dev-tools.nix`, `home-manager/config/tmux/tmux.conf`, or anything else. Only the new file + the one import line.

## Files to Modify
- `nixos/home.nix` — add one import line (Task 3).

## New Files
- `nixos/home-manager/modules/tmux-popups.nix` — packages, three `writeShellApplication` launchers, and the `toolsMenu` block appended to tmux via `lib.mkAfter` (Task 2).

## Critical Nix string-interpolation notes (apply in Task 2)
- The `toolsMenu` value is a Nix `''...''` multi-line string.
  - `${popPosting}` / `${popLazygit}` / `${popHarlequin}` → **Nix interpolates the store paths** (this is desired).
  - `#{pane_current_path}` and `#[bold]` → Nix leaves `#{`/`#[` untouched; **tmux** expands them (desired).
  - A trailing `\` at end of line is a **literal** in the Nix string and serves as a **tmux line-continuation** (desired).
- Store paths contain no spaces → `display-popup -E <store-path>` needs **no quoting** inside the tmux command.
- Do not accidentally write `''${` (Nix would escape the `$`); the store-path interpolations are plain `${...}` on a normal line.

## Why `writeShellApplication` instead of the repo's `home.file.".local/bin/x".source` convention
- Each launcher gets its own PATH closure via `runtimeInputs`, so `git`/`lazygit`/`posting`/`harlequin`/`fd` resolve regardless of the popup's environment (the classic NixOS popup-PATH footgun). The menu references each by absolute store path, which is robust and needs no PATH. Note this intentional deviation from `scripts.nix` convention in the file's comments.
- `writeShellApplication` already injects strict Bash mode by default (`set -euo pipefail` via its default `bashOptions`). Do **not** add `set -euo pipefail` manually to the `text` blocks — it is redundant. The scripts' existing guards (`|| pwd`, and `fd`/`[ -d ]` used only inside `if`/`&&` conditions) are already errexit-safe.

## Dependencies
- Task 2 (new module) must exist before Task 3 imports it. Task 1 (branch) should come first. Task 4 is a non-action (constraint).
- No external code depends on these files; the change is additive.

## Risks / verification points
1. **(Verified, low)** `extraConfig` is `types.lines` → `lib.mkAfter` merges, does not conflict with the plain string in `dev-tools.nix`. Confirmed against the home-manager module in the nix store. (Fallback if it ever changes: move the whole `programs.tmux` block into `tmux-popups.nix` and read the static conf there — but that would touch `dev-tools.nix`, which is undesired; current approach is correct.)
2. **(Low)** Editor/sub-process env: tools that spawn `$EDITOR` (posting, lazygit) inherit the tmux server's env. `EDITOR=nvim` is set in `shell.nix` `bashrcExtra` and inherited by the tmux server, so this works in practice. Flag if the user launches tmux from a non-interactive context.
3. **(Low)** `fd --max-results 1` availability: `fd` 8.x in nixpkgs supports it. If a future fd dropped it, detection still works via `fd`'s exit code alone — simply drop `--max-results 1` (slightly slower scan, still correct).
4. **(Low)** An empty convention dir (e.g. `.posting` exists but has no `*.posting.yaml`) → `posting --collection <dir>` opens an empty collection. Acceptable; matches decision #4.
5. **(Cosmetic)** The `display-popup` size is fixed at `80%x80%` for all three tools; easy to tune later per-tool.

## Validation (USER rebuilds — do not run `nix*` yourself, per AGENTS.md)
1. **Syntax/lint:** the executor may run the formatter `nixpkgs-fmt` on the two files (allowed; it's a formatter, not a nix build command) — confirm no unintended reflow beyond the touched lines.
2. **Build/activate (user):** from `/etc/nixos` (or repo root) the user runs `sudo nixos-rebuild test` (or `home-manager switch --flake .#kajdo`). This installs the packages, the launchers, and the tmux config.
3. **Manual tmux checks (user, inside tmux):**
   - `prefix + t` → centered **Tools** menu appears.
   - `prefix + T` → clock-mode still opens (clock-mode preserved).
   - `prefix + s` → session selector (`choose-tree -Zs`) still works (unchanged).
   - In the menu, press `r` → posting opens in a popup rooted at the pane cwd; `q` closes it.
   - Press `g` → lazygit opens (and at the repo toplevel when invoked from a subdir).
   - Press `s` → harlequin opens in a popup rooted at the pane cwd.
   - `Esc`/cancel closes the menu without launching.
   - Posture check: create a project dir with a `*.posting.yaml` (or `.posting/` dir) and confirm posting opens that collection; from a dir without one, confirm it falls back to the global default.

## Acceptance criteria
- [ ] `prefix + t` shows a centered Tools menu; `prefix + T` opens clock-mode.
- [ ] Selecting `r`/`g`/`s` opens posting/lazygit/harlequin in a popup at the pane's cwd; popup closes on tool exit (`q`).
- [ ] The user's existing `prefix + s` session selector still works unchanged.
- [ ] Posting uses a project collection when detectable, else the global default.
- [ ] lazygit opens at the repo toplevel.
- [ ] `dev-tools.nix` and `tmux.conf` are unchanged; only one new file + one import line added. Work is on branch `feat/tmux-tool-popups`.
```
acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Plan scopes exactly to the locked feature: one new module (home-manager/modules/tmux-popups.nix) + one import line in home.nix; explicitly forbids touching dev-tools.nix/tmux.conf and forbids running nix commands. No scope widening; full module code, exact edits, and verification notes provided."
    }
  ],
  "changedFiles": [],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    { "command": "git rev-parse --show-toplevel; ls .pi/plans; grep .gitignore", "result": "passed", "summary": "Resolved project root (/home/kajdo/git/nix-setup), confirmed .pi/plans convention at nixos/ level, and gitignore status." },
    { "command": "tmux list-keys -T prefix (inherited)", "result": "passed", "summary": "Authoritative key map: t=clock-mode, s=choose-tree -Zs, r=refresh-client; free lowercase = a b e g v y." },
    { "command": "grep extraConfig .../home-manager.../modules/programs/tmux.nix", "result": "passed", "summary": "Confirmed programs.tmux.extraConfig is types.lines and config assembled with mkBefore/mkAfter -> lib.mkAfter merges, not conflicts." }
  ],
  "validationOutput": [
    "Plan is a design artifact; no code changed (planning-only subagent). Validation deferred to user rebuild per AGENTS.md."
  ],
  "residualRisks": [
    "Editor/sub-process env in popup depends on tmux server inheriting EDITOR (set in shell.nix bashrcExtra) — works when tmux is started from the normal interactive shell.",
    "fd --max-results 1 availability — fallback is to drop the flag (exit-code-based detection still works)."
  ],
  "noStagedFiles": true,
  "diffSummary": "No files changed by planner. Plan written to /home/kajdo/git/nix-setup/nixos/.pi/plans/plan.md (gitignored). Earlier in run, .gitignore gained a '.pi/plans/' entry under pi-generated artifacts.",
  "reviewFindings": [
    "no blockers"
  ],
  "manualNotes": "Project root for pi artifacts resolved to the nixos/ config root (/home/kajdo/git/nix-setup/nixos) per existing .pi/plans convention (prior plan files already live there), not the git toplevel. .pi/plans/ now gitignored. Phase A (context-builder) was skipped because all context and decisions were already locked in the parent conversation; this planner was dispatched directly (Phase B). Oracle review (Phase C) still pending in the parent orchestrator."
}
```
