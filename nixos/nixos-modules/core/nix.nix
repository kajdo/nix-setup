{ config, pkgs, ... }:

{
  # Nix settings for development
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.download-buffer-size = 1048576000;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # NixOS release version for stateful data
  # Before changing, read: man configuration.nix or https://nixos.org/nixos/options.html
  system.stateVersion = "24.11";
}
