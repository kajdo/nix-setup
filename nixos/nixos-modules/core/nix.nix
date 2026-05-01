{ config, pkgs, ... }:

{
  # Nix settings for development
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.download-buffer-size = 1048576000;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # TODO: Remove when gomuks in nixpkgs is updated to v0.4+ (migrated away from libolm)
  # See: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/go/gomuks/package.nix
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  # NixOS release version for stateful data
  # Before changing, read: man configuration.nix or https://nixos.org/nixos/options.html
  system.stateVersion = "24.11";
}
