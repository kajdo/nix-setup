{ config, pkgs, ... }:

{
  # Battery life - Better scheduling for CPU cycles - thanks System76!!!
  services.system76-scheduler.settings.cfsProfiles.enable = true;

  # Enable TLP (better than gnomes internal power manager)
  services.tlp = {
    enable = true;
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
    };
  };

  # Enable powertop
  powerManagement.powertop.enable = true;

  # Enable thermald (only necessary if on Intel CPUs)
  services.thermald.enable = true;

  # enable backlight settings
  # brightnessctl set 30%  --> set to 30%
  # brightnessctl set +30%  --> increase by 30%
  # brightnessctl set 30%-  --> decrease by 30%
  environment.systemPackages = with pkgs; [
    brightnessctl
  ];
  users.users.kajdo.extraGroups = [ "video" "input" ]; # for brightnessctl to work
}