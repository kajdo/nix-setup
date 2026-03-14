{ config, pkgs, ... }:

{
  # System packages that must stay at system level
  environment.systemPackages = with pkgs; [
    evtest # Test input devices for key codes
    toybox # CLI utilities (must stay system-level due to gcc-wrapper conflicts)

    # GTK Themes
    gtk3
    gtk-engine-murrine
    gtk_engines
    adwaita-icon-theme

    # Notifications
    libnotify

    # GPU drivers
    mesa
  ];

  # Flatpak integration
  environment.sessionVariables = {
    XDG_DATA_DIRS = [ "/var/lib/flatpak/exports/share" "/home/$USER/.local/share/flatpak/exports/share" ];
  };
}
