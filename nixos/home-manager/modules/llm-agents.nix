# https://github.com/numtide/llm-agents.nix
{ config, pkgs, inputs, ... }:

{
  home.packages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
  ];
}
