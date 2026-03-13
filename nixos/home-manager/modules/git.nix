{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.delta
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Juergen Kajdocsy";
        email = "juergen.kajdocsy@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      credential = {
        helper = "store";
      };

      pull = {
        rebase = false;
      };

      core = {
        pager = "delta";
      };

      interactive = {
        diffFilter = "delta --color-only";
      };

      delta = {
        navigate = true;
        dark = true;
        side-by-side = true;
      };

      merge = {
        conflictstyle = "zdiff3";
      };

      fetch = {
        prune = true;
      };
    };
  };
}
