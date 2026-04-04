{ config, pkgs, lib, ... }:

{
  programs.bash = {
    enable = true;
    
    shellAliases = {
      # update
      UU = "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch";
      
      # override lsd's ll to include hidden files
      # ll = lib.mkForce "lsd -lA";
      
      # fun stuff
      ss = "/home/kajdo/git/stream-sports/get";
      ssl = "/home/kajdo/git/stream-sports/live-get";
      neofetch = "fastfetch";
      wget = "wget2";
      cat = "bat -p";
      
      wifi-list = "nmcli d wifi list";
      docker-ip = "sudo docker inspect -f \"{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}\"";
      
      # ls aliases handled by programs.lsd in cli-utils.nix
      
      # personal
      occ = "opencode --continue";
      
      # individual starters
      wttr = "clear && curl wttr.in";
      dns = "grep '^nameserver' /run/systemd/resolve/resolv.conf";
      govcurrent = "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor";
      governors = "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors";
      
      # development
      py = "python -c \"import sys; print(eval(sys.argv[1]))\"";
      
      # misc
      clock = "tty-clock -c -C 4";
      
      # tmux
      cmux = "tmux new -As";
      dmux = "tmux kill-session -t";
    };
    
    bashrcExtra = ''
      # ~/.bashrc: executed by bash(1) for non-login shells.

      # If not running interactively, don't do anything
      case $- in
          *i*) ;;
          *) return ;;
      esac

      # don't put duplicate lines or lines starting with space in the history.
      HISTCONTROL=ignoreboth

      # append to the history file, don't overwrite it
      shopt -s histappend

      # history length
      HISTSIZE=1000
      HISTFILESIZE=2000

      # check the window size after each command
      shopt -s checkwinsize

      # set variable identifying the chroot you work in
      if [ -z "''${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
          debian_chroot=$(cat /etc/debian_chroot)
      fi

      # set a fancy prompt (non-color, unless we know we "want" color)
      case "$TERM" in
          xterm-color | *-256color) color_prompt=yes ;;
      esac

      # set EDITOR to nvim
      export EDITOR="nvim"

      force_color_prompt=yes

      if [ -n "$force_color_prompt" ]; then
          if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
              color_prompt=yes
          else
              color_prompt=
          fi
      fi

      if [ "$color_prompt" = yes ]; then
          PS1=''${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w \''$\[\033[00m\] '
      else
          PS1=''${debian_chroot:+($debian_chroot)}\u@\h:\w\''$ '
      fi
      unset color_prompt force_color_prompt

      # If this is an xterm set the title to user@host:dir
      case "$TERM" in
          xterm* | rxvt*)
              PS1="\[\e]0;''${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
              ;;
      esac

      # enable color support of ls and also add handy aliases
      if [ -x /usr/bin/dircolors ]; then
          test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
          alias ls='ls --color=auto'
          alias grep='grep --color=auto'
          alias fgrep='fgrep --color=auto'
          alias egrep='egrep --color=auto'
      fi

      # Alias definitions (managed by home-manager shellAliases)
      # aliases not meant for dotfiles (user-specific)
      if [ -f ~/.aliases ]; then
          . ~/.aliases
      fi

      # user credentials (not in repo)
      if [ -f ~/.cred ]; then
          . ~/.cred
      fi

      # set bat as manpager
      export MANPAGER='nvim +Man!'

      # enable programmable completion features
      if ! shopt -oq posix; then
          if [ -f /usr/share/bash-completion/bash_completion ]; then
              . /usr/share/bash-completion/bash_completion
          elif [ -f /etc/bash_completion ]; then
              . /etc/bash_completion
          fi
      fi

      # Fuzzy search with ripgrep and open in editor
      # Usage: gg <search_term>
      gg() {
          if [ -z "$1" ]; then
              echo "Usage: gg_search <search_term>"
              return 1
          fi

          rg --line-number --no-heading --color=always -i -w --hidden "$1" . |
              fzf --ansi \
                  --delimiter ':' \
                  --preview 'bat --style=numbers --color=always --highlight-line {2} --line-range +{2}: {1}' \
                  --preview-window 'up,60%,border-bottom' \
                  --bind 'enter:execute(eval exec ''${EDITOR:-nvim} +{2} {1})' \
                  --bind 'ctrl-c:abort' \
                  --bind 'ctrl-u:preview-half-page-up' \
                  --bind 'ctrl-d:preview-half-page-down'
      }

      # open opencode with oh-my-opencode as plugins
      omo() {
          local config_file="$HOME/.config/opencode/config.json"
          local updated_json

          updated_json=$(jq '
            .plugin = (
              (.plugin // [])
              | if any(.[]; test("^oh-my-opencode(@.*)?$")) then
                  .
                else
                  . + ["oh-my-opencode@latest"]
                end
            )
          ' "$config_file")

          OPENCODE_CONFIG_CONTENT="$updated_json" opencode "$@"
        }


      # add individual paths
      export PATH="/usr/local/bin:$PATH"
      export PATH="$PATH:/home/kajdo/git/custom_scripts/remote_computing/.local/bin"
      export PATH="$HOME/.nix-profile/bin:$PATH"
      export PATH="$HOME/.cargo/bin:$PATH"
      export PATH=$PATH:$HOME/.local/bin

      # pipx thingy
      export _ZO_DOCTOR=0

      # keybindings
      bind -x '"\C-p": pi'

      # zoxide, mcfly, starship inits handled by home-manager enableBashIntegration
    '';
  };
}
