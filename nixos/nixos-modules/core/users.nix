{ config, pkgs, ... }:

{
  # User account
  users.users.kajdo = {
    isNormalUser = true;
    description = "kajdo";

    # Keep the user's systemd manager running after logout / at boot so
    # user-scoped services (e.g. the restic backup timer) run unattended.
    linger = true;
    # dialout: serial port access (e.g. flashing firmware via browser/WebSerial)
    extraGroups = [ "networkmanager" "wheel" "video" "docker" "dialout" ];
    packages = with pkgs; [
      makima
    ];
  };

  # System packages that must stay at system level
  # (due to gcc-wrapper conflicts or system requirements)
  environment.systemPackages = with pkgs; [
    evtest # Test input devices for key codes
    toybox # CLI utilities (system-level required)
  ];
}
