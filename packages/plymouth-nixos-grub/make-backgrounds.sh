#!/usr/bin/env bash
# Build the splash backgrounds from the NixOS GRUB theme background. The
# heading and help line are baked in with the same fonts and positions GRUB
# uses, so switching from GRUB to the splash only changes the words.
# Usage: make-backgrounds.sh <grub background.png> <ubuntu font dir> <out dir>
set -euo pipefail

grub_background=$1
fonts=$2
out=$3

body=#282828
help_color=#c4c4c4

mkdir -p "$out"

# Keep the NixOS header band and clear the GRUB text below it.
magick "$grub_background" -fill "$body" -draw "rectangle 0,240 1919,1079" "$out/blank.png"

help_line=$(mktemp --suffix=.png)
magick -background none -fill "$help_color" -font "$fonts/Ubuntu-R.ttf" -pointsize 20.6 \
  label:"Press Esc to show boot messages" -trim +repage "$help_line"
magick "$out/blank.png" "$help_line" -gravity North -geometry +0+1024 -composite "$out/base.png"
rm "$help_line"

heading() {
  local name=$1 text=$2 image
  image=$(mktemp --suffix=.png)
  magick -background none -fill white -font "$fonts/Ubuntu-B.ttf" -pointsize 34 \
    label:"$text" -trim +repage "$image"
  magick "$out/base.png" "$image" -geometry +286+284 -composite "$out/$name.png"
  rm "$image"
}

heading unlock "Enter your passphrase to start"
heading boot "Starting NixOS"
heading shutdown "Shutting down"

rm "$out/blank.png"
