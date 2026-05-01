{ pkgs, ... }:

{
  # Matrix messaging (TUI client)
  home.packages = with pkgs; [
    gomuks
  ];

  # Custom keybindings (vim-style scrolling)
  xdg.configFile."gomuks/keybindings.yaml".source = ./../config/gomuks/keybindings.yaml;
}
