{ config, pkgs, ... }:

{
  imports = [
    ./home-manager/modules/cli-utils.nix
    ./home-manager/modules/dev-tools.nix
    ./home-manager/modules/hyprland.nix
    ./home-manager/modules/media-apps.nix
    ./home-manager/modules/desktop-apps.nix
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
