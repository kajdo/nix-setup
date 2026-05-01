# /etc/nixos/flake.nix
 {
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
      home-manager = {
        # url = "github:nix-community/home-manager/release-25.05";
        url = "github:nix-community/home-manager/master";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      llm-agents.url = "github:numtide/llm-agents.nix";
      windsurf.url = "github:Exafunction/windsurf.nvim";
      windsurf.inputs.nixpkgs.follows = "nixpkgs";
    };

   outputs = { self, nixpkgs, nixpkgs-stable, home-manager, ... } @inputs :
   let
     system = "x86_64-linux";
     stable-pkgs = nixpkgs-stable.legacyPackages.${system};
   in {

     nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          inherit system;

           modules = [
             { nixpkgs.overlays = [
                 # Use stable deno (prebuilt rusty-v8) to avoid building V8 from source
                 (final: prev: {
                   yt-dlp = prev.yt-dlp.override { deno = stable-pkgs.deno; };
                   mpv = prev.mpv.override { yt-dlp = final.yt-dlp; };
                 })
                 (final: prev: {
                   codeium-lsp = inputs.windsurf.packages.${prev.stdenv.hostPlatform.system}.codeium-lsp;
                 })
               ];
             }
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.kajdo = {
                  imports = [ (import ./home.nix) ];
                  _module.args.inputs = inputs;
                };
                backupFileExtension = "backup";
              };
            }
         ];

           specialArgs = { inherit inputs; };
        };
     };
   };
 }
