{ pkgs, ... }:
{
  # Link your kitty configuration
  xdg.configFile."kitty/kitty.conf" = {
    source = ./../config/kitty/kitty.conf;
  };

  # Ensure kitty is installed
  home.packages = with pkgs; [
    kitty
  ];
}
