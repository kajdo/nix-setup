{ config, pkgs, ... }:

{
  # Intel graphics configuration for hardware encoding
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa                    # OpenGL implementation
      intel-media-driver      # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver      # LIBVA_DRIVER_NAME=i965 (older, better for Firefox/Chromium)
      libvdpau-va-gl
    ];
  };
}
