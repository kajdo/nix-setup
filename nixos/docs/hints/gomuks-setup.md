# Gomuks - Terminal Matrix Client

Gomuks is a TUI Matrix client written in Go with Vim-like keybindings and full E2EE support.

## First launch setup

Launch `gomuks` — on first run it presents a login screen.

1. Enter your homeserver URL (e.g. `https://matrix.org`)
2. Enter your username and password (or use SSO)
3. Gomuks stores credentials in `~/.local/share/gomuks/`

## Key bindings

| Key | Action |
|-----|--------|
| `i` | Open message composer (insert mode) |
| `Enter` | Send message |
| `Esc` | Exit composer / cancel |
| `h/l` | Switch between room list and chat |
| `j/k` | Navigate (room list or messages) |
| `g` | Scroll to top |
| `G` | Scroll to bottom |
| `/` | Search |
| `:join #room:matrix.org` | Join a room |
| `:quit` | Quit gomuks |

## Useful commands (in command mode `:`)

| Command | Description |
|---------|-------------|
| `/join <room>` | Join a room |
| `/leave` | Leave current room |
| `/create <name>` | Create a new room |
| `/devices` | List devices |
| `/logout` | Logout and clear session |

## Persistent sessions

Gomuks keeps running as long as the terminal is open. For persistence:

```bash
tmux new -s matrix
gomuks
# detach with Ctrl+B then D
# reattach later: tmux attach -t matrix
```

## Files

- Package definition: `home-manager/modules/messaging.nix`
- Config dir: `~/.config/gomuks/`
- Data dir: `~/.local/share/gomuks/`
