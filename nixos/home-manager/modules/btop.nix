{ config, pkgs, ... }: 
{
  programs.btop = {
    enable = true;
    # https://github.com/aristocratos/btop#configurability
    settings = {
      color_theme = "Default";
      theme_background = false;
      truecolor = true;
      graph_symbol = "braille";
    };
  };
}
