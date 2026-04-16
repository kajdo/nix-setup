# Main NixOS system configuration.
# Imports all system-level modules organized by category:
# core, hardware, networking, desktop, and services.

{ config, pkgs, inputs, ... }:

let
  # Define the individual build packages
in {
  imports = [
    # Hardware configuration (auto-generated)
    ./hardware-configuration.nix

    # Core system configuration
    ./nixos-modules/core/boot.nix
    ./nixos-modules/core/nix.nix
    ./nixos-modules/core/users.nix
    ./nixos-modules/core/localization.nix

    # Hardware support
    ./nixos-modules/hardware/graphics.nix
    ./nixos-modules/hardware/audio.nix
    ./nixos-modules/hardware/bluetooth.nix
    ./nixos-modules/hardware/power.nix
    ./nixos-modules/hardware/video.nix

    # Networking
    ./nixos-modules/networking/networking.nix

    # Desktop environment
    ./nixos-modules/desktop/display.nix
    ./nixos-modules/desktop/fonts.nix
    ./nixos-modules/desktop/integration.nix

    # System services
    ./nixos-modules/services/printing.nix
    ./nixos-modules/services/virtualization.nix
  ];
}
