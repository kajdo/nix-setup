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
####### ~/nixos-config/flake.nix (ADAPTED - NO DEV SHELLS)
# {
#   description = "Your NixOS configuration with opencode-ai";
#
#   inputs = {
#     nixpkgs.url = "nixpkgs/nixos-unstable"; # It's good to keep this updated, or pin to a specific stable branch
#   };
#
#   outputs = inputs@{ self, nixpkgs, ... }:
#     let
#       # Define the system architecture
#       system = "x86_64-linux"; # Or "aarch64-linux" for ARM
#
#       # Import nixpkgs for the specified system
#       pkgs = nixpkgs.legacyPackages.${system};
#
#       # Import our custom opencode-ai package definition
#       # Adjusted path to your preferred location: ./nixos/flakes/opencode-ai
#       opencode-ai-package = pkgs.callPackage ./flakes/opencode-ai {
#         # No specific versions of dependencies being passed currently,
#         # so it will use the default versions from the chosen nixpkgs.
#       };
#
#     in
#     {
#       # 1. NixOS Configuration (your existing setup)
#       nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
#         inherit system;
#         specialArgs = { inherit inputs; }; # Pass inputs to configuration.nix
#         modules = [
#           ./configuration.nix
#         ];
#       };
#
#       # 2. Custom Packages (where opencode-ai will live)
#       packages.${system} = {
#         # This makes 'opencode-ai' installable via 'nix profile install .#opencode-ai'
#         opencode-ai = opencode-ai-package;
#
#         # You can also set a default package for convenience if you only have one.
#         # This makes it installable via 'nix profile install .'
#         default = opencode-ai-package;
#       };
#
#       # No devShells output as per your request
#     };
# }
