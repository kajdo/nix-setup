{ config, pkgs, ... }:

{
  # Real-time kit for PulseAudio/Pipewire
  security.rtkit.enable = true;

  # Pipewire audio server
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # WirePlumber: disable node suspend to prevent audio delay on resume
    # (fixes 1-3s mic delay in browser-based calls like Teams)
    wireplumber.extraConfig = {
      "10-disable-suspend" = {
        "monitor.alsa.rules" = [{
            matches = [
              { "node.name" = "~alsa_input.*"; }
              { "node.name" = "~alsa_output.*"; }
            ];
            actions = {
              update-props = {
                "session.suspend-timeout-seconds" = 0;
              };
            };
          }
        ];
      };

      # Disable Bluetooth node suspend and minimize processing for calls
      "10-bluetooth-nosuspend" = {
        "monitor.bluez.rules" = [{
            matches = [
              { "node.name" = "~bluez_output.*"; }
              { "node.name" = "~bluez_input.*"; }
            ];
            actions = {
              update-props = {
                "session.suspend-timeout-seconds" = 0;
                "dither.method" = "none";
              };
            };
          }
        ];
      };

      # Prefer high-quality Bluetooth codecs for better call audio
      "11-bluetooth-codecs" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-msbc" = true;
          "bluez5.enable-sbc-xq" = true;
        };
      };
    };
  };

  # Audio utilities
  environment.systemPackages = with pkgs; [
    pulseaudio  # for pactl commands
  ];
}
