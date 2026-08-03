# Restic backup of the personal data depot.
#
# Source:  ~/Nextcloud/clean_depot
# Target:  sftp:nvmeberry:/home/kajdo/BACKUP/depot  (existing SSH cert auth as user kajdo)
#
# The repository is encrypted with a password stored OUTSIDE this repo
# (never tracked in git): ~/.config/restic/depot.pwd  (mode 0600).
# Create it once, manually:
#   install -m600 /dev/stdin ~/.config/restic/depot.pwd <<< 'your-strong-password'
#
# Scheduling runs as a systemd USER unit (this module), so it runs as
# `kajdo` and reuses the existing SSH keys. To run while logged out,
# lingering is enabled in nixos-modules/core/users.nix.
#
# A helper wrapper `restic-depot` is generated with the same environment
# as the timer, e.g.:
#   restic-depot snapshots
#   restic-depot mount /mnt/restic
#   restic-depot restore latest --target /tmp/restore

{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    restic
  ];

  # Home Manager's restic module is gated behind this enable flag
  # (unlike the NixOS module). Without it, no units/timer/wrapper are generated.
  services.restic.enable = true;

  services.restic.backups.depot = {
    # Initialize the remote repo on first run (idempotent afterwards)
    initialize = true;

    repository = "sftp:nvmeberry:/home/kajdo/BACKUP/depot";
    passwordFile = "${config.home.homeDirectory}/.config/restic/depot.pwd";

    paths = [
      "${config.home.homeDirectory}/Nextcloud/clean_depot"
    ];

    # Retention: ~17 snapshots kept (7 daily + 4 weekly + 6 monthly)
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true; # catch up after suspend / offline
    };
  };
}
