# /etc/nixos/flake.nix
{
   inputs = {
     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
     readest-web-flake = {
       url = "path:./flakes/readest-web";
       # --- THIS IS THE FIX ---
       # This tells Nix to provide our `nixpkgs` flake input
       # as an input also named `nixpkgs` to the sub-flake.
       inputs.nixpkgs.follows = "nixpkgs";
     };
   };
  outputs = { self, nixpkgs, readest-web-flake, ... } @ inputs: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          readest-web-flake.nixosModules.readest-web
        ];
        specialArgs = { inherit inputs; };
      };
    };
  };
}
