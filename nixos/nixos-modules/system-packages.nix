{ config, pkgs, ... }:

{
  # enable appimages to be runable as in other distros
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.localsend.enable = true;
  programs.localsend.openFirewall = true;
  programs.firefox.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # avahi for chromecast
  services.avahi.enable = true;

  # usb mount in thunar
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.tumbler.enable = true;
  programs.thunar.enable = true; # Ensure Thunar is enabled
  programs.thunar.plugins = with pkgs; [
    thunar-volman
    # You might also want the trash plugin
    thunar-archive-plugin 
  ];

  # docker setup
  virtualisation.docker.enable = true;

  # virt-manager setup
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["kajdo"];


  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    evtest # test input like keyboard for key codes
    toybox # pgrep and other fun stuff
    lua
    unzip
    networkmanagerapplet
    # GTK Themes
    gtk3
    gtk-engine-murrine # For GTK theme engines
    gtk_engines
    adwaita-icon-theme
    papirus-icon-theme # Popular icon theme
    gnome-themes-extra
    # Notifications
    libnotify
    dunst # Works on Wayland
    # Also ensure OpenGL/Mesa drivers are correctly configured for your Intel GPU
    # You have some of this, but double check they are pulling in all needed parts
    mesa # This ensures all standard Mesa drivers are available

    curl      # Likely needed for network communication/authentication

    # appimage execution
    appimage-run
  ];

  # Set GTK environment variables
  environment.variables = {
    GTK_THEME = "Adwaita"; # Replace with your desired GTK theme
    GTK_ICON_THEME = "Adwaita"; # Replace with your desired icon theme
  };

  environment.sessionVariables = {
    PATH = [
      "/home/kajdo/.local/bin"
      "/home/kajdo/.npm-global/bin"
    ];
    XDG_DATA_DIRS = [ "/var/lib/flatpak/exports/share" "/home/$USER/.local/share/flatpak/exports/share" ];
  };
}
