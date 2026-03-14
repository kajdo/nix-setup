{ config, pkgs, ... }:

{
  # Docker
  virtualisation.docker.enable = true;

  # virt-manager (KVM/QEMU)
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = [ "kajdo" ];
}
