{ config, pkgs, ... }:

{
  # System packages that must stay at system level
  environment.systemPackages = with pkgs; [
    evtest # Test input devices for key codes
    toybox # CLI utilities (must stay system-level due to gcc-wrapper conflicts)
  ];
}
