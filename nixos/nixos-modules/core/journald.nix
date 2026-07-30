{ config, pkgs, ... }:

{
  # Cap persistent journal size and retention.
  # Prevents runaway growth from chatty services (e.g. containers logging at
  # DEBUG) from rotating out genuinely useful entries.
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=1month
  '';
}
