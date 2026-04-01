# /etc/nixos/flake.nix
 {
    inputs = {
      nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      home-manager = {
        # url = "github:nix-community/home-manager/release-25.05";
        url = "github:nix-community/home-manager/master";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      llm-agents.url = "github:numtide/llm-agents.nix";
    };

   outputs = { self, nixpkgs, home-manager, ... } @inputs : {

     nixosConfigurations = {
       nixos = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";

         modules = [
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
