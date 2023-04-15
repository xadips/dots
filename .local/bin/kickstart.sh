#!/bin/bash
#
# Arch Linux installation
#
# Bootable USB:
# - [Download](https://archlinux.org/download/) ISO and GPG files
# - Verify the ISO file: `$ pacman-key -v archlinux-<version>-dual.iso.sig`
# - Create a bootable USB with: `# dd if=archlinux*.iso of=/dev/sdX && sync`
#
# UEFI setup:
#
# - Set boot mode to UEFI, disable Legacy mode entirely.
# - Disable Secure Boot.
# - Set SATA operation to AHCI mode.
#
# Run installation:
#
# - Connect to wifi via: `# iwctl station wlan0 connect WIFI-NETWORK`
# - Run: `# bash <(curl -sL https://raw.githubusercontent.com/xadips/dots/main/.local/bin/kickstart.sh)`

set -uo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log" >&2)

export SNAP_PAC_SKIP=y

# Dialog
BACKTITLE="Arch Linux installation"

get_input() {
    title="$1"
    description="$2"

    input=$(dialog --clear --stdout --backtitle "$BACKTITLE" --title "$title" --inputbox "$description" 0 0)
    echo "$input"
}

get_password() {
    title="$1"
    description="$2"

    init_pass=$(dialog --clear --stdout --backtitle "$BACKTITLE" --title "$title" --passwordbox "$description" 0 0)
    : ${init_pass:?"password cannot be empty"}

    test_pass=$(dialog --clear --stdout --backtitle "$BACKTITLE" --title "$title" --passwordbox "$description again" 0 0)
    if [[ "$init_pass" != "$test_pass" ]]; then
        echo "Passwords did not match" >&2
        exit 1
    fi
    echo $init_pass
}

get_choice() {
    title="$1"
    description="$2"
    shift 2
    options=("$@")
    dialog --clear --stdout --backtitle "$BACKTITLE" --title "$title" --menu "$description" 0 0 0 "${options[@]}"
}

echo -e "\n### Checking UEFI boot mode"
if [ ! -f /sys/firmware/efi/fw_platform_size ]; then
    echo >&2 "You must boot in UEFI mode to continue"
    exit 2
fi

echo -e "\n### Setting up clock"
timedatectl set-ntp true
hwclock --systohc --utc
echo -e "\n### Setting mirrors"
reflector -c Lithuania,Latvia,Poland -a 6 --sort rate --save /etc/pacman.d/mirrorlist

echo -e "\n### Installing additional tools"
pacman -Sy --noconfirm --needed git terminus-font dialog wget

clear
font="ter-716n"
setfont "$font"

hostname=$(get_input "Hostname" "Enter hostname") || exit 1
clear
: ${hostname:?"hostname cannot be empty"}

user=$(get_input "User" "Enter username") || exit 1
clear
: ${user:?"user cannot be empty"}

password=$(get_password "User" "Enter password") || exit 1
clear
: ${password:?"password cannot be empty"}

noyes=("Yes" "The System is RAID1" "No" "Single drive setup")
raid=$(get_choice "Drive status" "Do you want RAID1 for 2 drives?" "${noyes[@]}") || exit 1

devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac | tr '\n' ' ')
read -r -a devicelist <<<$devicelist

fdevice=$(get_choice "Installation" "Select installation disk" "${devicelist[@]}") || exit 1
[[ "$raid" == "Yes" ]] && sdevice=$(get_choice "Installation" "Select secoond RAID1 device" "${devicelist[@]}") || exit 1

clear

echo -e "\n### Setting up partitions"
umount -R /mnt 2>/dev/null || true

lsblk -plnx size -o name "${fdevice}" | xargs -n1 wipefs --all
[[ "$raid" == "Yes" ]] && lsblk -plnx size -o name "${sdevice}" | xargs -n1 wipefs --all
sgdisk --clear "${fdevice}" --new 1:0:+500Mib --typecode 1:ef00 "{fdevice}" --new 2:0:0 "${fdevice}"
sgdisk --change-name-name=1:ESP --change-name=2:primary "${fdevice}"
[[ "$raid" == "Yes" ]] && sgdisk --clear "${sdevice}" --new 1:0:+500Mib --typecode 1:ef00 "{sdevice}" --new 2:0:0 "${sdevice}"
[[ "$raid" == "Yes" ]] && sgdisk --change-name-name=1:ESP --change-name=2:primary "${sdevice}"

fpart_boot="$(ls ${fdevice}* | grep -E "^${fdevice}p?1$")"
fpart_root="$(ls ${fdevice}* | grep -E "^${fdevice}p?2$")"

[[ "$raid" == "Yes" ]] && spart_boot="$(ls ${sdevice}* | grep -E "^${sdevice}p?1$")"
[[ "$raid" == "Yes" ]] && spart_root="$(ls ${sdevice}* | grep -E "^${sdevice}p?2$")"

echo -e "\n### Formatting partitions"
mkfs.vfat -n "EFI" -F 32 "${fpart_boot}"
[[ "$raid" == "Yes" ]] && mkfs.vfat -n "EFI" -F 32 "${spart_boot}"

[[ "$raid" == "Yes" ]] && mkfs.btrfs -m raid1 -d raid1 "{$fpart_root}" "${spart_root}" || mkfs.btrfs -L btrfs -m single -d single "${fpart_root}"

echo -e "\n### Setting up BTRFS subvolumes"
mount "${fpart_root}" /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
umount /mnt

mount -o noatime,nodiratime,compress-force=zstd,space_cache=v2,subvol=@ "${fpart_root}" /mnt
mkdir -p /mnt/{boot/efi,home,.snapshots,var/log}

mount -o noatime,nodiratime,compress-force=zstd,space_cache=v2,subvol=@home "${fpart_root}" /mnt/home
mount -o noatime,nodiratime,compress-force=zstd,space_cache=v2,subvol=@snapshots "${fpart_root}" /mnt/.snapshots
mount -o noatime,nodiratime,compress-force=zstd,space_cache=v2,subvol=@var_log "${fpart_root}" /mnt/var/log
mount "${fpart_boot}" /mnt/boot/efi

echo -e "\n### Installing packages"
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware vim amd-ucode grub grub-btrfs efibootmgr networkmanager network-manager-applet dialog wpa_supplicant mtools dosfstools git reflector snapper bluez bluez-utils cups btrfs-progs base-devel xdg-utils xdg-user-dirs pipewire pipewire-pulse pipewire-alsa wireplumber easyeffects inetutils libpulse mesa zsh zsh-completions inotify-tools hyprland yadm hyprland xorg-xwayland mako xdg-desktop-portal-hyprland thunar polkit-kde-agent qt5-wayland qt6-wayland rsync kitty neofetch snap-pac keychain kernel-modules-hook

echo "FONT=$font" >/mnt/etc/vconsole.conf
genfstab -L /mnt >>/mnt/etc/fstab
echo "${hostname}" >/mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" >>/mnt/etc/locale.gen
ln -sf /usr/share/zoneinfo/Europe/Vilnius /mnt/etc/localtime
arch-chroot /mnt locale-gen

echo -e "\n### Setting up initramfs and boot"
cat <<EOF >/mnt/etc/mkinitcpio.conf
MODULES=()
BINARIES=(setfont)
FILES=()
HOOKS=(base consolefont udev autodetect kms modconf block filesystems keyboard grub-btrfs-overlayfs)
EOF
arch-chroot /mnt mkinitcpio -p linux-zen
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
[[ "$raid" == "Yes" ]] && dd if="${fpart_boot}" of="${spart_boot}" && arch-chroot /mnt efibootmgr --create --disk "${sdevice}" --part 1 -w --label GRUB2 --loader '\EFI\GRUB\grubx64.efi'

echo -e "\n### Creating user"
arch-chroot /mnt useradd -mG wheel,network,video,input -s /usr/bin/zsh "$user"
arch-chroot /mnt chsh -s /usr/bin/zsh
echo "$user:$password" | arch-chroot /mnt chpasswd
echo "$user ALL=(ALL) ALL" | sudo EDITOR='tee -a' visudo

if [ "${user}" = "spidax" ]; then
    echo -e "\n### Cloning dotfiles"
    arch-chroot /mnt sudo -u $user bash -c 'git clone https://github.com/xadips/dots.git ~/.dotfiles'
    arch-chroot /mnt systemctl enable NetworkManager
    arch-chroot /mnt systemctl enable NetworkManager-wait-online.service

    echo -e "\n### DONE - reboot and yadm bootstrap"
fi

umount -R /mnt
