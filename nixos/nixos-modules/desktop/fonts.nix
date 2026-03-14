{ config, pkgs, ... }:

{
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.symbols-only
    noto-fonts
    noto-fonts-color-emoji
    atkinson-hyperlegible-next
    atkinson-hyperlegible-mono
  ];
}
