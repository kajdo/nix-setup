{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # Python tooling
    python313
    python313Packages.flake8
    pipx

    # Build tools
    gcc
    gnumake
    cargo

    # Lua tooling
    luajitPackages.luarocks_bootstrap

    # User utilities
    yt-dlp
    scrcpy
    opencode

    # General utilities
    jq
    xdg-utils
    wget2
  ];
}
