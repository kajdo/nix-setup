{ config, pkgs, ... }:

{
  # Better CPU scheduling (System76)
  services.system76-scheduler.settings.cfsProfiles.enable = true;

  # TLP power management (better than GNOME's internal)
  services.tlp = {
    enable = true;
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
    };
  };

  # Power usage diagnostics
  powerManagement.powertop.enable = true;

  # Thermal management for Intel CPUs
  services.thermald.enable = true;

  # Backlight control
  # brightnessctl set 30%   --> set to 30%
  # brightnessctl set +30%  --> increase by 30%
  # brightnessctl set 30%-  --> decrease by 30%
  environment.systemPackages = with pkgs; [
    brightnessctl
  ];

  # Permissions for brightnessctl
  users.users.kajdo.extraGroups = [ "video" "input" ];
}
