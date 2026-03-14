{ config, pkgs, ... }:

{
  # User account
  users.users.kajdo = {
    isNormalUser = true;
    description = "kajdo";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    packages = with pkgs; [
      makima
    ];
  };

  # System packages that must stay at system level
  # (due to gcc-wrapper conflicts or system requirements)
  environment.systemPackages = with pkgs; [
    evtest   # Test input devices for key codes
    toybox   # CLI utilities (system-level required)
  ];
}
