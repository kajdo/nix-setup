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
  };
}
