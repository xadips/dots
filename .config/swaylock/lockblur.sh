#!/bin/bash

grim /tmp/lock_background.png
convert -blur 0x1.5 /tmp/lock_background.png /tmp/lock_background_post_processed.png && rm /tmp/lock_background.png
swaylock -f --config "$XDG_CONFIG_HOME"/swaylock/config -i /tmp/lock_background_post_processed.png
