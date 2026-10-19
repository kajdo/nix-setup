{ config, pkgs, ... }:

{
  # Git workflow scripts
  home.file.".local/bin/show_git_url".source = ./../scripts/show_git_url;
  home.file.".local/bin/create_feature".source = ./../scripts/create_feature;
  home.file.".local/bin/delete_feature".source = ./../scripts/delete_feature;
  home.file.".local/bin/finalize_feature".source = ./../scripts/finalize_feature;
  home.file.".local/bin/merge_feature".source = ./../scripts/merge_feature;
  home.file.".local/bin/git_list_orphants".source = ./../scripts/git_list_orphants;
  home.file.".local/bin/rollback_git".source = ./../scripts/rollback_git;
  home.file.".local/bin/reb".source = ./../scripts/reb;

  # Nix-related scripts
  home.file.".local/bin/nix-deepclean".source = ./../scripts/nix-deepclean;
  home.file.".local/bin/find_codium".source = ./../scripts/find_codium;
  home.file.".local/bin/patch_codium".source = ./../scripts/patch_codium;
  home.file.".local/bin/lush".source = ./../scripts/lush;
  home.file.".local/bin/lull".source = ./../scripts/lull;
  home.file.".local/bin/strip_emojis.py".source = ./../scripts/strip_emojis.py;

  # Desktop/wayland scripts (some may need cleanup later)
  home.file.".local/bin/brightness_down".source = ./../scripts/brightness_down;
  home.file.".local/bin/brightness_up".source = ./../scripts/brightness_up;
  home.file.".local/bin/volume_down".source = ./../scripts/volume_down;
  home.file.".local/bin/volume_up".source = ./../scripts/volume_up;
  home.file.".local/bin/volume_mute_toggle".source = ./../scripts/volume_mute_toggle;
  home.file.".local/bin/scratch_kitty".source = ./../scripts/scratch_kitty;
  home.file.".local/bin/scratch".source = ./../scripts/scratch;
  home.file.".local/bin/set_random_wallpaper.sh".source = ./../scripts/set_random_wallpaper.sh;
  home.file.".local/bin/sus".source = ./../scripts/sus;
  home.file.".local/bin/toggle_touchpad".source = ./../scripts/toggle_touchpad;
  home.file.".local/bin/dwm_autostart_cmd.sh".source = ./../scripts/dwm_autostart_cmd.sh;

  # Rofi scripts
  home.file.".local/bin/rofi_bluetooth.sh".source = ./../scripts/rofi_bluetooth.sh;
  home.file.".local/bin/rofi_bluetooth_info.sh".source = ./../scripts/rofi_bluetooth_info.sh;
  home.file.".local/bin/rofi_launch.sh".source = ./../scripts/rofi_launch.sh;
  home.file.".local/bin/rofi-wifi-menu.sh".source = ./../scripts/rofi-wifi-menu.sh;

  # Bluetooth headset prep + mid-call recovery for browser calls (Teams)
  home.file.".local/bin/rofi_call_prep.sh".source = ./../scripts/rofi_call_prep.sh;
  home.file.".local/bin/bt_audio_guard.sh".source = ./../scripts/bt_audio_guard.sh;

  # Background watcher: auto-heal a BT headset parked at profile 'off'
  # (connected, but no audio sink — e.g. after a failed post-call A2DP
  # switch-back). Recovers via rofi_call_prep.sh music after a 30s debounce.
  systemd.user.services.bt-audio-guard = {
    Unit = {
      Description = "Auto-recover Bluetooth headset parked at profile off";
      After = [ "pipewire.service" "wireplumber.service" ];
    };
    Service = {
      ExecStart = "${config.home.homeDirectory}/.local/bin/bt_audio_guard.sh";
      Restart = "always";
      RestartSec = "30";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Media/utility scripts
  home.file.".local/bin/vid".source = ./../scripts/vid;
}
