{ config, pkgs, ... }:

{
  # CLI Utilities
  home.packages = with pkgs; [
    unzip
    appimage-run

    # Terminal tools
    cmatrix
    ncdu
    stow
    tree
    tty-clock
  ];

  # bat - cat replacement with syntax highlighting
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
    };
  };

  # btop - resource monitor
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "Default";
      theme_background = false;
      truecolor = true;
      graph_symbol = "braille";
    };
  };

  # cava - audio visualizer
  programs.cava = {
    enable = true;
  };

  # fastfetch - system info tool
  programs.fastfetch = {
    enable = true;
  };

  # fzf - command-line fuzzy finder
  programs.fzf = {
    enable = true;
  };

  # lsd - ls replacement with icons
  programs.lsd = {
    enable = true;
    enableBashIntegration = true;
  };

  # zoxide - smarter cd command
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };
}
