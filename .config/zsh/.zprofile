#!/usr/bin/env zsh

[[ "$TTY" == /dev/tty* ]] || return 0

export $(systemctl --user show-environment)
# VM variable for software rendering
# export WLR_RENDERER_ALLOW_SOFTWARE=1
export GPG_TTY=$(tty)
export LIBSEAT_BACKEND=logind
# Ensure SSH_AUTH_SOCK points to systemd socket if using systemd ssh-agent
if [[ -z "$SSH_AUTH_SOCK" ]] && [[ -n "$XDG_RUNTIME_DIR" ]]; then
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi
systemctl --user import-environment GPG_TTY LIBSEAT_BACKEND SSH_AUTH_SOCK

# Start Hyprland on tty1 if not already running
if [[ -z $DISPLAY && -z $WAYLAND_DISPLAY && "$TTY" == "/dev/tty1" ]]; then
    # Set session type before starting
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=Hyprland
    export XDG_CURRENT_DESKTOP=Hyprland
    
    # Import environment to systemd before starting
    systemctl --user import-environment XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_CURRENT_DESKTOP
    
    # Check if Hyprland is already running (prevents multiple instances)
    if ! pgrep -x Hyprland >/dev/null; then
        # Start Hyprland with systemd-cat for logging
        systemd-cat -t hyprland -p info Hyprland
    fi
fi
