# /etc/nixos/pkgs/dwmblocks.nix
{ stdenv, fetchFromGitHub, gcc, xorg }:

stdenv.mkDerivation rec {
  name = "dwmblocks";
  src = ./source/blocks-kajdo; # Path to your dwmblocks source

  buildInputs = [ gcc xorg.libX11 ]; # Add X11 development headers

  installPhase = ''
    mkdir -p $out/bin
    cp dwmblocks $out/bin
  '';
}
