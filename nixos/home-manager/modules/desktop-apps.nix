{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Calculator
    gnome-calculator

    # Office suite
    libreoffice-qt6-fresh

    # Note-taking
    obsidian

    # Finance tracking
    portfolio

    # Messaging
    signal-desktop
  ];

  # Web browser
  programs.firefox.enable = true;

  # Email client
  programs.thunderbird = {
    enable = true;

    profiles = {
      default = {
        isDefault = true;

        # Enable userChrome.css support
        settings = {
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };

        # Your existing userChrome.css content
        userChrome = ''
          @namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");

          #tabs-toolbar {
              display: none !important;
              visibility: collapse !important;
              height: 0px !important;
              min-height: 0px !important;
              max-height: 0px !important;
              margin: 0px !important;
              padding: 0px !important;
          }

          #unified-toolbar {
              display: none !important;
              visibility: collapse !important;
              height: 0px !important;
              min-height: 0px !important;
              max-height: 0px !important;
          }

          #tabmail-tabs {
              display: none !important;
              visibility: collapse !important;
              height: 0px !important;
              min-height: 0px !important;
              max-height: 0px !important;
              margin: 0px !important;
              padding: 0px !important;
          }

          #tabmail-arrowscrollbox {
              display: none !important;
              visibility: collapse !important;
              height: 0px !important;
              min-height: 0px !important;
          }

          .tabmail-tab {
              display: none !important;
              height: 0px !important;
              min-height: 0px !important;
          }

          .tab-background {
              display: none !important;
              height: 0px !important;
              min-height: 0px !important;
          }

          .tab-background-start,
          .tab-background-middle,
          .tab-background-end {
              display: none !important;
              height: 0px !important;
              min-height: 0px !important;
          }

          .tab-background-start[selected=true]::after,
          .tab-background-start[selected=true]::before,
          .tab-background-end[selected=true]::after,
          .tab-background-end[selected=true]::before,
          .tab-background-middle {
              min-height: 0px !important;
          }

          .tab-line {
              display: none !important;
              height: 0px !important;
          }

          .tabmail-tab::after,
          .tabmail-tab::before {
              border: none !important;
              height: 0px !important;
              display: none !important;
          }

          #navigation-toolbox #tabmail-tabs,
          #navigation-toolbox #tabmail-arrowscrollbox {
              display: none !important;
              visibility: collapse !important;
              height: 0px !important;
              min-height: 0px !important;
          }

          #navigation-toolbox::before,
          #navigation-toolbox::after,
          #tabs-toolbar::before,
          #tabs-toolbar::after {
              display: none !important;
              height: 0px !important;
              min-height: 0px !important;
          }
        '';
      };
    };
  };

  # Terminal file manager
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;

    # Theme: use catppuccin-mocha flavor
    theme = {
      flavor.dark = "catppuccin-mocha";
    };

    # Flavors: catppuccin-mocha
    flavors = {
      catppuccin-mocha = ./../config/yazi/flavors/catppuccin-mocha.yazi;
    };

    # Settings (yazi.toml content)
    settings = {
      mgr = {
        ratio = [ 2 2 6 ];
        sort_by = "mtime";
        sort_sensitive = false;
        sort_reverse = true;
        sort_dir_first = true;
        sort_translit = false;
        linemode = "none";
        show_hidden = false;
        show_symlink = true;
        scrolloff = 5;
        mouse_events = [ "click" "scroll" ];
        title_format = "Yazi: {cwd}";
      };

      preview = {
        wrap = "no";
        tab_size = 2;
        max_width = 920;
        max_height = 900;
        cache_dir = "";
        image_delay = 30;
        image_filter = "triangle";
        image_quality = 75;
        sixel_fraction = 15;
        ueberzug_scale = 1;
        ueberzug_offset = [ 0 0 0 0 ];
      };

      input.cursor_blink = false;
      log.enabled = false;
    };
  };

  # Yazi keymap (complex, keep as file)
  xdg.configFile."yazi/keymap.toml".source = ./../config/yazi/keymap.toml;
}
