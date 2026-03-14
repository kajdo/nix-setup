{ config, pkgs, ... }:

{
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # CLI tools for PulseAudio compatibility (pactl, etc.)
  environment.systemPackages = [ pkgs.pulseaudio ];
}