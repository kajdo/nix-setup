{ config, pkgs, lib, ... }:

{
  options.services.makima = {
    enable = lib.mkEnableOption "Enable the Makima keyboard remapping daemon.";
  };

  config = lib.mkIf config.services.makima.enable {
    systemd.services.makima = {
      description = "Makima remapping daemon";
      after = [ "graphical.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        # Log the environment and then run makima
        ExecStart = "${pkgs.coreutils}/bin/env > /var/log/makima.log && ${pkgs.sudo}/bin/sudo -E MAKIMA_CONFIG=/root/.config/makima ${pkgs.makima}/bin/makima";
        User = "root";
        Group = "input";
        StandardOutput = "append:/var/log/makima.log";
        StandardError = "append:/var/log/makima.log";
      };
    };

    environment.systemPackages = [ pkgs.makima ];
  };
}
