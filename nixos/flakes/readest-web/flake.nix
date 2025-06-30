# /etc/nixos/flakes/readest-web/flake.nix
{
  description = "Readest Web App container using surf";

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
        
        buildInputs = with pkgs; [
          surf
          noto-fonts
          dejavu_fonts
          roboto
        ];

        dontUnpack = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          mkdir -p $out/share/applications
          mkdir -p $out/share/icons/hicolor/512x512/apps

          # The wrapper ensures the fonts in `buildInputs` are available to surf
          makeWrapper ${pkgs.surf}/bin/surf $out/bin/readest-web \
            --add-flags "https://web.readest.com/"

          install -D -m644 ${readest-icon} $out/share/icons/hicolor/512x512/apps/readest-web.png

          cat > $out/share/applications/readest-web.desktop <<EOF
          [Desktop Entry]
          Name=Readest (Web)
          Comment=Ebook reader (Web version using surf)
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
