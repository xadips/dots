#!/usr/bin/env zsh

[[ "$TTY" == /dev/tty* ]] || return 0

export $(systemctl --user show-environment)
# VM variable for software rendering
# export WLR_RENDERER_ALLOW_SOFTWARE=1
export GPG_TTY=$(tty)
export LIBSEAT_BACKEND=logind
systemctl --user import-environment GPG_TTY LIBSEAT_BACKEND

if [[ -z $DISPLAY && "$TTY" == "/dev/tty1" ]]; then
    systemd-cat -t hyprland Hyprland
    systemctl --user stop graphical-session.target
    systemctl --user unset-environment DISPLAY WAYLAND_DISPLAY
fi
