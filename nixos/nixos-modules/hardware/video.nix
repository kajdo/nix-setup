{ config, ... }:

{
  # Virtual webcam via v4l2loopback kernel module
  # Used with scrcpy to forward Android camera as a webcam device
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=2 card_label="Virtual Webcam" exclusive_caps=1
  '';
}
