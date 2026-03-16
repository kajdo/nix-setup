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

  # Media/utility scripts
  home.file.".local/bin/vid".source = ./../scripts/vid;
}
