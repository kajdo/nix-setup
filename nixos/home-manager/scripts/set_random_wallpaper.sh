#!/usr/bin/env bash

# Define the directory containing the images
WALLPAPER_DIR="$HOME/Bilder/backgrounds/"

# Select a random image from the directory (only top level, only image files)
SELECTED_WALLPAPER=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f -regex '.*\.\(jpg\|jpeg\|png\|bmp\|tiff\|svg\)$' | shuf -n 1)

# Set the selected image as the background using feh
feh --bg-fill "$SELECTED_WALLPAPER"

