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
    ./nixos-modules/user-packages.nix
    ./nixos-modules/system-packages.nix
    ./nixos-modules/development.nix
  ];
}
