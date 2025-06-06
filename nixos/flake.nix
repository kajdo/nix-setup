# /etc/nixos/flake.nix
 {
   inputs = {
     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
   };

   outputs = { self, nixpkgs, ... } @ inputs: {
     nixosConfigurations = {
       nixos = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";

         modules = [
           ./configuration.nix
         ];

         # Pass inputs to the module system
         specialArgs = { inherit inputs; };
       };
     };
   };
 }
