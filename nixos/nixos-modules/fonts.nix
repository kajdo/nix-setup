{ config, pkgs, ... }:

{
  # Font setup
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
      noto-fonts
      atkinson-hyperlegible-next
      atkinson-hyperlegible-mono
    ];
  };
}
