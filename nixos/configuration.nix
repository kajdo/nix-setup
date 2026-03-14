{ config, pkgs, inputs, ... }:

let
  # Define the individual build packages
in {
  imports = [
    ./hardware-configuration.nix
    ./nixos-modules/boot.nix
    ./nixos-modules/networking.nix
    ./nixos-modules/localization.nix
    ./nixos-modules/display.nix
    ./nixos-modules/power.nix
    ./nixos-modules/audio.nix
    ./nixos-modules/bluetooth.nix
    ./nixos-modules/fonts.nix
    ./nixos-modules/graphics.nix
    ./nixos-modules/flatpak.nix
    ./nixos-modules/virtualization.nix
    ./nixos-modules/desktop-services.nix
    ./nixos-modules/desktop-programs.nix
    ./nixos-modules/users.nix
    ./nixos-modules/system-packages.nix
    ./nixos-modules/nix.nix
  ];
}
