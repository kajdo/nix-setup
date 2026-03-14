{ config, pkgs, ... }:

{
  imports = [
    ./home-manager/modules/cli-utils.nix
    ./home-manager/modules/dev-tools.nix
    ./home-manager/modules/feh.nix
    ./home-manager/modules/gnome-calculator.nix
    ./home-manager/modules/git.nix
    ./home-manager/modules/kitty.nix
    ./home-manager/modules/lazydocker.nix
    ./home-manager/modules/libreoffice.nix
    ./home-manager/modules/mcfly.nix
    ./home-manager/modules/media-apps.nix
    ./home-manager/modules/nextcloud.nix
    ./home-manager/modules/nvim.nix
    ./home-manager/modules/pulsemixer.nix
    ./home-manager/modules/signal.nix
    ./home-manager/modules/starship.nix
    ./home-manager/modules/theming.nix
    ./home-manager/modules/thunderbird.nix
    ./home-manager/modules/tldr.nix
    ./home-manager/modules/tmux.nix
    ./home-manager/modules/wayland.nix
    ./home-manager/modules/yazi.nix
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
