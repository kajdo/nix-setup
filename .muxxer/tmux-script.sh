#!/usr/bin/env bash
# Default muxxer tmux session script
# Creates the default 3-pane development layout for a new session.

LEFT_TOP_PANE="$(tmux display-message -p '#{pane_id}')"

tmux split-window -h -t "$LEFT_TOP_PANE"
RIGHT_PANE="$(tmux display-message -p '#{pane_id}')"

tmux select-pane -t "$LEFT_TOP_PANE"
tmux split-window -v -t "$LEFT_TOP_PANE"
LEFT_BOTTOM_PANE="$(tmux display-message -p '#{pane_id}')"

tmux resize-pane -y 5 -t "$LEFT_BOTTOM_PANE"

# --- ADD YOUR COMMANDS HERE ---

# Left top pane: main development pane
tmux send-keys -t "$LEFT_TOP_PANE" "nix-shell" C-m
# sleep 10
tmux send-keys -t "$LEFT_TOP_PANE" "clear && glow README.md" C-m

# Right pane: documentation, logs, or auxiliary tools
tmux send-keys -t "$RIGHT_PANE" "nix-shell" C-m
# sleep 10
tmux send-keys -t "$RIGHT_PANE" "opencode --continue" C-m

# Left bottom pane: local shell for quick commands
# Example: identify the pane purpose
tmux send-keys -t "$LEFT_BOTTOM_PANE" "clear" C-m

tmux select-pane -t "$LEFT_TOP_PANE"
