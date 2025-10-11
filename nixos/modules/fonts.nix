{ config, pkgs, ... }:

{
  # Font setup
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      noto-fonts-emoji
      nerd-fonts.symbols-only
      noto-fonts-extra
      atkinson-hyperlegible-next
      atkinson-hyperlegible-mono
    ];
  };
}