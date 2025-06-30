# /etc/nixos/flakes/readest-web/flake.nix
{
  description = "Readest Web App container using Chromium";

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      readest-icon = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/readest/readest/main/apps/readest-app/public/icon.png";
        sha256 = "sha256-lOiZ0btcSuYeQ1LbfelYjm/mlycfh5fPqGBCKrqcUVg=";
      };

      webappPackage = pkgs.stdenv.mkDerivation {
        pname = "readest-web";
        version = "1.0";

        nativeBuildInputs = [ pkgs.makeWrapper ];
        
        # --- THIS IS THE FINAL FIX ---
        # Provide both chromium AND the necessary fonts to the wrapper.
        buildInputs = with pkgs; [
          chromium
          dejavu_fonts
          noto-fonts
          roboto
        ];

        dontUnpack = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          mkdir -p $out/share/applications
          mkdir -p $out/share/icons/hicolor/512x512/apps

          # The makeWrapper command ensures that the fonts from buildInputs
          # are available to the chromium process.
          makeWrapper ${pkgs.chromium}/bin/chromium $out/bin/readest-web \
            --add-flags "--app=https://web.readest.com/"

          install -D -m644 ${readest-icon} $out/share/icons/hicolor/512x512/apps/readest-web.png

          cat > $out/share/applications/readest-web.desktop <<EOF
          [Desktop Entry]
          Name=Readest (Web)
          Comment=Ebook reader (Web version using Chromium)
          Exec=readest-web
          Icon=readest-web
          Terminal=false
          Type=Application
          Categories=Office;Viewer;
          EOF
          runHook postInstall
        '';
      };
    in
    {
      packages.${system}.default = webappPackage;
      
      nixosModules.readest-web = { config, lib, ... }: {
        environment.systemPackages = [ self.packages.${system}.default ];
      };
    };
}
