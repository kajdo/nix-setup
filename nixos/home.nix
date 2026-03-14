{ config, pkgs, ... }:

{
  imports = [
    ./home-manager/modules/bat.nix
    ./home-manager/modules/btop.nix
    ./home-manager/modules/yazi.nix
    ./home-manager/modules/mcfly.nix
    ./home-manager/modules/mpv.nix
    ./home-manager/modules/fzf.nix
    ./home-manager/modules/git.nix
    ./home-manager/modules/starship.nix
    ./home-manager/modules/tmux.nix
    ./home-manager/modules/lsd.nix
    ./home-manager/modules/tty-clock.nix
    ./home-manager/modules/tldr.nix
    ./home-manager/modules/stow.nix
    ./home-manager/modules/pulsemixer.nix
    ./home-manager/modules/feh.nix
    ./home-manager/modules/ncdu.nix
    ./home-manager/modules/cmatrix.nix
    ./home-manager/modules/cava.nix
    ./home-manager/modules/cli-utils.nix
    ./home-manager/modules/tree.nix
    ./home-manager/modules/glow.nix
    ./home-manager/modules/lazydocker.nix
    ./home-manager/modules/gnome-calculator.nix
    ./home-manager/modules/peazip.nix
    ./home-manager/modules/zoxide.nix
    ./home-manager/modules/obsidian.nix
    ./home-manager/modules/portfolio.nix
    ./home-manager/modules/grim.nix
    ./home-manager/modules/theming.nix
    ./home-manager/modules/slurp.nix
    ./home-manager/modules/swappy.nix
    ./home-manager/modules/wl-clipboard.nix
    ./home-manager/modules/wl-clip-persist.nix
    ./home-manager/modules/nextcloud.nix
    ./home-manager/modules/moonlight.nix
    ./home-manager/modules/pyradio.nix
    ./home-manager/modules/ueberzugpp.nix
    ./home-manager/modules/fastfetch.nix
    ./home-manager/modules/thunderbird.nix
    ./home-manager/modules/nvim.nix
    ./home-manager/modules/dev-tools.nix
    ./home-manager/modules/kitty.nix
    ./home-manager/modules/wayland.nix
    ./home-manager/modules/libreoffice.nix
    ./home-manager/modules/signal.nix
  ];

  home.username = "kajdo";
  home.homeDirectory = "/home/kajdo";
  home.stateVersion = "25.11";

  # User-specific PATH additions
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];
}
