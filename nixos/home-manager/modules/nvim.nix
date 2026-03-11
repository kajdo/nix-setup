{ config, pkgs, ... }:
{
  # Link your nvim configuration
  xdg.configFile."nvim" = {
    source = ./../config/nvim;
    recursive = true;
  };

  # Ensure neovim is installed
  home.packages = with pkgs; [
    neovim
  ];
}
