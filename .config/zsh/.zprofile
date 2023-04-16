#!/usr/bin/env zsh

[[ "$TTY" == /dev/tty* ]] || return 0

export $(systemctl --user show-environment)

if [[ -z $DISPLAY && "$TTY" == "/dev/tty1" ]]; then
    systemd-cat -t hyprland Hyprland
    systemctl --user stop graphical-session.target
    systemctl --user unset-environment DISPLAY WAYLAND_DISPLAY
fi
