{ config, pkgs, ... }: 
{

  # necessary because
  # > mktemp: Unknown option 'dry-run' (see "mktemp --help")
  home.packages = with pkgs; [
    coreutils
  ];

  programs.mcfly = {
    enable = true;
    enableBashIntegration = true;
  };
}
