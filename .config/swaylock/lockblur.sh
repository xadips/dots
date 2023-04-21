#!/bin/bash

grim -t jpeg -q 50 /tmp/lock_background.jpeg
convert -blur 0x1.5 /tmp/lock_background.jpeg /tmp/lock_background_post_processed.jpeg && rm /tmp/lock_background.jpeg
swaylock -f --config "$HOME"/.config/swaylock/config -i /tmp/lock_background_post_processed.jpeg
