{ config, pkgs, ... }: {
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchDocked = "ignore";
    lidSwitchExternalPower = "suspend";
    # Explicitly override HandlePowerKey
    powerKey = "suspend";
  };

  services.acpid.enable = true;

  boot.kernelParams = [ "acpi_osi=" "acpi_backlight=vendor" ];
}
