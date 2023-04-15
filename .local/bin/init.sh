#!/bin/bash

set -e
exec 2> >(while read line; do echo -e "\e[01;31m$line\e[0m"; done)

script_name="$(basename "$0")"
dotfiles_dir="$(
    cd "$(dirname "$0")"
    pwd
)"
cd "$dotfiles_dir"

if (("$EUID")); then
    sudo -s "$dotfiles_dir/$script_name" "$@"
    exit 0
fi

if [ "$1" = "-r" ]; then
    echo >&2 "Running in reverse mode!"
    reverse=1
fi

copy() {
    if [ -z "$reverse" ]; then
        orig_file="$dotfiles_dir/$1"
        [ -n "$3" ] && dest_file="/$3" || dest_file="/$1"
    else
        [ -n "$3" ] && orig_file="/$3" || orig_file="/$1"
        dest_file="$dotfiles_dir/$1"
    fi

    mkdir -p "$(dirname "$orig_file")"
    mkdir -p "$(dirname "$dest_file")"

    rm -rf "$dest_file"

    cp -R "$orig_file" "$dest_file"
    if [ -z "$reverse" ]; then
        [ -n "$2" ] && chmod "$2" "$dest_file"
    else
        chown -R maximbaz "$dest_file"
    fi
    echo "$dest_file <= $orig_file"
}

is_chroot() {
    ! cmp -s /proc/1/mountinfo /proc/self/mountinfo
}

systemctl_enable() {
    echo "systemctl enable "$1""
    systemctl enable "$1"
}

systemctl_enable_start() {
    echo "systemctl enable --now "$1""
    systemctl enable "$1"
    systemctl start "$1"
}

echo ""
echo "============================"
echo "Setting up /usr/local/bin..."
echo "============================"

copy "usr/local/bin/checkluksheader"
copy "usr/local/bin/backup-repo"

echo ""
echo "=========================="
echo "Setting up /etc configs..."
echo "=========================="

copy "etc/conf.d/snapper"
copy "etc/pacman.conf" 644 "etc/pacman.conf"
copy "etc/pacman.d/hooks"
copy "etc/systemd/system/getty@tty1.service.d/override.conf"
copy "etc/xdg/reflector/reflector.conf"

(("$reverse")) && exit 0

echo ""
echo "================================="
echo "Enabling and starting services..."
echo "================================="

sysctl --system >/dev/null

systemctl daemon-reload
systemctl_enable_start "bluetooth.service"
systemctl_enable_start "btrfs-scrub@-.timer"
systemctl_enable_start "btrfs-scrub@home.timer"
systemctl_enable_start "btrfs-scrub@.snapshots.timer"
systemctl_enable_start "linux-modules-cleanup.service"
systemctl_enable_start "reflector.service"
systemctl_enable_start "snapper-cleanup.timer"
systemctl_enable_start "grub-btrfsd.timer"

if is_chroot; then
    echo >&2 "=== Running in chroot, skipping dns setup..."
else
    nmcli con mod $(nmcli con | grep 'ethernet' | awk '{ print $4 }') ipv4.dns "1.1.1.1 1.0.0.1"
    systemctl restart NetworkManager
fi

echo "Configuring NTP"
timedatectl set-ntp true

echo "Configuring aurutils"
mkdir -p /etc/aurutils
ln -sf /etc/pacman.conf "/etc/aurutils/pacman-maximbaz-local.conf"
ln -sf /etc/pacman.conf "/etc/aurutils/pacman-$(uname -m).conf"
