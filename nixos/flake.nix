# /etc/nixos/flake.nix
 {
   inputs = {
     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
     # readest-flake.url = "path:./flakes/readest";
     readest-web-flake.url = "path:./flakes/readest-web";
   };

  outputs = { self, nixpkgs, readest-web-flake, ... } @ inputs: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          ./configuration.nix
          # readest-flake.nixosModules.readest
          readest-web-flake.nixosModules.readest-web
        ];

        specialArgs = { inherit inputs; };
      };
    };
  };
}
