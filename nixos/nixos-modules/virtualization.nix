{ config, pkgs, ... }:

{
  # Docker setup
  virtualisation.docker.enable = true;

  # virt-manager setup
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["kajdo"];
}
