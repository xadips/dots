#!/bin/bash

set -e
exec 2> >(while read line; do echo -e "\e[01;31m$line\e[0m"; done)
user="spidax"
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
        chown -R $user "$dest_file"
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
echo "Installing pacman packages..."
echo "============================"

copy "etc/pacman.conf" 644 "etc/pacman.conf"
pacman -Syu --noconfirm --needed snapper inetutils xdg-utils xdg-user-dirs ydotool cronie pipewire pipewire-pulse pipewire-alsa pipewire-jack pipewire-audio wireplumber easyeffects helvum mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader zsh-completions zsh-syntax-highlighting zsh-theme-powerlevel10k hyprland xorg-xwayland xdg-desktop-portal-hyprland polkit-kde-agent qt5-wayland qt6-wayland rsync kitty neofetch snap-pac keychain kernel-modules-hook dunst ripgrep bat yt-dlp mpv gnupg firefox thunar zathura zathura-pdf-mupdf zathura-djvu udiskie hyprpaper swaylock imv libnotify wl-clipboard qt5ct qt6ct kvantum-theme-materia materia-gtk-theme papirus-icon-theme wine-staging winetricks giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs samba dosbox gstreamer-vaapi ttf-liberation lib32-systemd steam noto-fonts-emoji android-tools libreoffice-fresh mlocate

echo ""
echo "============================"
echo "Setting up /usr/local/bin..."
echo "============================"

echo ""
echo "=========================="
echo "Setting up /etc configs..."
echo "=========================="

copy "etc/snapper/configs/root" 640 etc/snapper/configs/root
copy "etc/conf.d/snapper" 644 etc/conf.d/snapper
# copy "etc/pacman.d/hooks"
copy "etc/systemd/system/getty@tty1.service.d/activate-numlock.conf"
copy "etc/systemd/system/getty@tty1.service.d/override.conf"
copy "etc/xdg/reflector/reflector.conf"
copy "etc/plymouth/plymouthd.conf"
copy "etc/updatedb.conf"

echo ""
echo "==================================="
echo "Rebuilding initramfs for plymouth..."
echo "==================================="

mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg

(("$reverse")) && exit 0

echo ""
echo "================================="
echo "Enabling and starting services..."
echo "================================="

# Kernel?
# sysctl --system >/dev/null

systemctl daemon-reload
systemctl_enable_start "bluetooth.service"
systemctl_enable_start "cups.service"
systemctl_enable_start "btrfs-scrub@-.timer"
systemctl_enable_start "btrfs-scrub@home.timer"
systemctl_enable_start "btrfs-scrub@.snapshots.timer"
systemctl_enable_start "linux-modules-cleanup.service"
systemctl_enable_start "reflector.service"
systemctl_enable_start "snapper-cleanup.timer"
systemctl_enable_start "snapper-timeline.timer"
systemctl_enable_start "grub-btrfsd.service"
systemctl_enable_start "cronie.service"

if is_chroot; then
    echo >&2 "=== Running in chroot, skipping dns setup..."
else
    nmcli con mod $(nmcli con | grep 'ethernet' | awk '{ print $4 }') ipv4.dns "1.1.1.1 1.0.0.1"
    systemctl restart NetworkManager
fi

echo "Configuring NTP"
timedatectl set-ntp true
