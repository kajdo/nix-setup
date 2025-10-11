{ config, pkgs, inputs, ... }:

let
  # Define the individual build packages
  # dwmblocks    = pkgs.callPackage ./pkgs/dwmblocks.nix {};
  # st           = pkgs.callPackage ./pkgs/st.nix {};
in {
  imports = [
    ./hardware-configuration.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/localization.nix
    ./modules/display.nix
    ./modules/power.nix
    ./modules/audio.nix
    ./modules/bluetooth.nix
    ./modules/fonts.nix
    ./modules/graphics.nix
    ./modules/flatpak.nix
    ./modules/user-packages.nix
    ./modules/system-packages.nix
    ./modules/development.nix
  ];
}