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

    # WirePlumber 0.5 exposes the Bluetooth mic through a loopback source node
    # (built by CreateDeviceLoopbackSource in scripts/monitors/bluez.lua) that
    # does NOT apply monitor.bluez.rules. So the exposed Audio/Source that call
    # apps (Teams) actually capture from never receives
    # session.suspend-timeout-seconds=0, suspends after 5s idle, and resumes
    # degraded at call start (1-3s mic delay — same class of bug as the rules
    # above, on a node the rules can't reach). Patch that one upstream script to
    # set the prop on the exposed node. Regenerated instantly from the cached
    # wireplumber package (no recompile); --replace-fail fails loudly if upstream
    # ever moves the matched line.
    wireplumber.configPackages = [
      (pkgs.runCommand "wp-bluez-loopback-nosuspend" { } ''
        mkdir -p "$out/share/wireplumber/scripts/monitors"
        substitute "${pkgs.wireplumber}/share/wireplumber/scripts/monitors/bluez.lua" \
          "$out/share/wireplumber/scripts/monitors/bluez.lua" \
          --replace-fail '["priority.session"] = 2010,' \
                         '["priority.session"] = 2010, ["session.suspend-timeout-seconds"] = 0,'
      '')
    ];
  };

  # Audio utilities
  environment.systemPackages = with pkgs; [
    pulseaudio  # for pactl commands
  ];
}
