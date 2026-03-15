# update
alias UU='cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch'

# fun stuff
alias ss='/home/kajdo/git/stream-sports/get'
alias ssl='/home/kajdo/git/stream-sports/live-get'
alias neofetch='fastfetch'
alias wget='wget2'
alias cat='bat -p'

alias wifi-list='nmcli d wifi list'
alias docker-ip='sudo docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'

# personal alias(es)
alias ls='lsd --group-dirs first'
alias occ='opencode --continue'

# individual starters
alias wttr='clear && curl wttr.in'
alias dns="grep '^nameserver' /run/systemd/resolve/resolv.conf"
alias govcurrent='cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
alias governors='cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors'

# development & ai fun
alias gg='lazygit'
alias py='python -c "import sys; print(eval(sys.argv[1]))"'

# some individual stuff
alias clock='tty-clock -c -C 4'

# Tmux aliases
alias cmux='tmux new -As'
alias dmux='tmux kill-session -t'
