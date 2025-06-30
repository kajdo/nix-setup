# /etc/nixos/flakes/readest/flake.nix
{
  description = "Readest AppImage package and NixOS module";

  inputs = {
    nixpkgs.url = "github.com/NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      readestPackage = let
        pname = "readest";
        version = "0.9.61"; // When a new version is released, update this.

        # Derivation to extract the AppImage contents
        appimageContents = pkgs.appimageTools.extractType2 {
          inherit pname version;
          src = pkgs.fetchurl {
            url = "https://download.readest.com/releases/v${version}/Readest_${version}_amd64.AppImage";
            // And update the sha256 here.
            sha256 = "ea0532226373c764a2c91dca8ba0b48b9213170466d80b3879cd1915237ce4f8";
          };
        };

      in
      # Derivation to wrap the AppImage and provide runtime dependencies
      pkgs.appimageTools.wrapType2 {
        inherit pname version;
        src = pkgs.fetchurl {
          url = "https://download.readest.com/releases/v${version}/Readest_${version}_amd64.AppImage";
          sha256 = "ea0532226373c764a2c91dca8ba0b48b9213170466d80b3879cd1915237ce4f8";
        };

        # Provides all necessary runtime libraries to fix the EGL error
        # once the upstream bug in the application is resolved.
        extraPkgs = pkgs: (with pkgs; [
          webkitgtk_4_1 gtk3 librsvg mesa pango cairo gdk-pixbuf at-spi2-atk
          gsettings-desktop-schemas glib gtk_engines
          gst_all_1.gstreamer gst_all_1.gst-plugins-good gst_all_1.gst-plugins-bad
          gst_all_1.gst-plugins-ugly gst_all_1.gst-libav
        ]);

        # Installs the desktop and icon files
        extraInstallCommands = ''
          install -D -m644 ${appimageContents}/Readest.desktop $out/share/applications/Readest.desktop
          install -D -m644 ${appimageContents}/Readest.png $out/share/icons/hicolor/256x256/apps/readest.png
        '';
      };
    in
    {
      packages.${system}.readest = readestPackage;

      nixosModules.readest = { config, lib, ... }: {
        environment.systemPackages = [ self.packages.${system}.readest ];
      };
    };
}
