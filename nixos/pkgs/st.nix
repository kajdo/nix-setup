# /etc/nixos/pkgs/st.nix
{ stdenv, fetchFromGitHub, gcc, xorg, fontconfig, harfbuzz, gd, glib, pkg-config }:

stdenv.mkDerivation rec {
  name = "st";
  # src = /home/kajdo/git/st-kajdo; # Path to your st source
  src = ./source/st-kajdo; # Path to your st source

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    gcc
    xorg.libX11
    xorg.libXft
    fontconfig
    harfbuzz
    gd
    glib
    glib.dev
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp st $out/bin
  '';
}
