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
# - Temporarily disable Secure Boot.
# - Make sure a strong UEFI administrator password is set.
# - Delete preloaded OEM keys for Secure Boot, allow custom ones.
# - Set SATA operation to AHCI mode.
#
# Run installation:
#
# - Connect to wifi via: `# iwctl station wlan0 connect WIFI-NETWORK`
# - Run: `# bash <(curl -sL https://git.io/maximbaz-install)`

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
reflector -c Lithuania -a 6 --sort rate --save /etc/pacman.d/mirrorlist

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
read -r -a devicelist <<< $devicelist

fdevice=$(get_choice "Installation" "Select installation disk" "${devicelist[@]}") || exit 1
[[ "$raid" == "Yes" ]] && sdevice=$(get_choice "Installation" "Select secoond RAID1 device" "${devicelist[@]}") || exit 1

clear

echo -e "\n### Setting up partitions"
umount -R /mnt 2> /dev/null || true

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


[[ "$raid" == "Yes" ]] &&

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

echo -e "\n### Configuring custom repo"
mkdir "/mnt/var/cache/pacman/${user}-local"
march="$(uname -m)"

if [[ "${user}" == "maximbaz" && "${hostname}" == "home-"* ]]; then
    wget -m -nH -np -q --show-progress --progress=bar:force --reject='index.html*' --cut-dirs=3 -P "/mnt/var/cache/pacman/${user}-local" "https://pkgbuild.com/~maximbaz/repo/${march}"
    rename -- 'maximbaz.' "${user}-local." "/mnt/var/cache/pacman/${user}-local"/*
else
    repo-add "/mnt/var/cache/pacman/${user}-local/${user}-local.db.tar"
fi

if ! grep "${user}" /etc/pacman.conf > /dev/null; then
    cat >> /etc/pacman.conf << EOF
[${user}-local]
Server = file:///mnt/var/cache/pacman/${user}-local
[maximbaz]
Server = https://pkgbuild.com/~maximbaz/repo/${march}
[options]
CacheDir = /mnt/var/cache/pacman/pkg
CacheDir = /mnt/var/cache/pacman/${user}-local
EOF
fi

echo -e "\n### Installing packages"
pacstrap -i /mnt maximbaz-base maximbaz-$(uname -m)

echo -e "\n### Generating base config files"
ln -sfT dash /mnt/usr/bin/sh

cryptsetup luksHeaderBackup "${luks_header_device}" --header-backup-file /tmp/header.img
luks_header_size="$(stat -c '%s' /tmp/header.img)"
rm -f /tmp/header.img

echo "cryptdevice=PARTLABEL=primary:luks:allow-discards cryptheader=LABEL=luks:0:$luks_header_size root=LABEL=btrfs rw rootflags=subvol=root quiet mem_sleep_default=deep" > /mnt/etc/kernel/cmdline

echo "FONT=$font" > /mnt/etc/vconsole.conf
genfstab -L /mnt >> /mnt/etc/fstab
echo "${hostname}" > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo "en_DK.UTF-8 UTF-8" >> /mnt/etc/locale.gen
ln -sf /usr/share/zoneinfo/Europe/Copenhagen /mnt/etc/localtime
arch-chroot /mnt locale-gen
cat << EOF > /mnt/etc/mkinitcpio.conf
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base consolefont udev autodetect modconf block encrypt-dh filesystems keyboard)
EOF
arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt arch-secure-boot initial-setup

echo -e "\n### Configuring swap file"
btrfs filesystem mkswapfile --size 4G /mnt/swap/swapfile
echo "/swap/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

echo -e "\n### Creating user"
arch-chroot /mnt useradd -m -s /usr/bin/zsh "$user"
for group in wheel network nzbget video input; do
    arch-chroot /mnt groupadd -rf "$group"
    arch-chroot /mnt gpasswd -a "$user" "$group"
done
arch-chroot /mnt chsh -s /usr/bin/zsh
echo "$user:$password" | arch-chroot /mnt chpasswd
arch-chroot /mnt passwd -dl root

echo -e "\n### Setting permissions on the custom repo"
arch-chroot /mnt chown -R "$user:$user" "/var/cache/pacman/${user}-local/"

if [ "${user}" = "maximbaz" ]; then
    echo -e "\n### Cloning dotfiles"
    arch-chroot /mnt sudo -u $user bash -c 'git clone --recursive https://github.com/maximbaz/dotfiles.git ~/.dotfiles'

    echo -e "\n### Running initial setup"
    arch-chroot /mnt /home/$user/.dotfiles/setup-system.sh
    arch-chroot /mnt sudo -u $user /home/$user/.dotfiles/setup-user.sh
    arch-chroot /mnt sudo -u $user zsh -ic true

    echo -e "\n### DONE - reboot and re-run both ~/.dotfiles/setup-*.sh scripts"
else
    echo -e "\n### DONE - read POST_INSTALL.md for tips on configuring your setup"
fi

echo -e "\n### Reboot now, and after power off remember to unplug the installation USB"
umount -R /mnt
