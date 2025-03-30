# /etc/nixos/flake.nix
 {
   inputs = {
     nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
     # nixvim.url = "github:nix-community/nixvim";
   };
 
   # outputs = { self, nixpkgs, nixvim, ... } @ inputs: {
   outputs = { self, nixpkgs, ... } @ inputs: {
     nixosConfigurations = {
       nixos = nixpkgs.lib.nixosSystem {
         system = "x86_64-linux";
 
         modules = [
           ./configuration.nix
           # nixvim.nixosModules.nixvim
         ];
 
         # Pass inputs to the module system
         specialArgs = { inherit inputs; };
       };
     };
   };
 }
