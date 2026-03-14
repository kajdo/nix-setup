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
  };

  # Audio utilities
  environment.systemPackages = with pkgs; [
    pulseaudio  # for pactl commands
  ];
}
