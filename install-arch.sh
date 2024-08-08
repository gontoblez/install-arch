#!/bin/bash

# Variables
DISK="/dev/sdX"         # make sure to change this before proceeding with installation
HOSTNAME="archlinux"    # set hostname here
USERNAME="user"         # make sure to set your username here
PASSWORD="password"     # you can change the password later
SWAP_SIZE="2G"
DISPLAY_MANAGER="ly"
PACKAGES="neovim alacritty zathura zathura-pdf-mupdf"
GUI_PACKAGES="sway swaybg swayidle swaylock xorg-server xorg-xwayland wayland-utils xorg-xinit xterm"
# ESSENTIAL_PACKAGES are not the base packages. There's no variable for base packages.
ESSENTIAL_PACKAGES="networkmanager base-devel linux-headers grub efibootmgr dosfstools os-prober mtools mesa"

# Update the system clock
timedatectl set-ntp true

# Partition the disks
parted ${DISK} -- mklabel gpt
parted ${DISK} -- mkpart primary fat32 1MiB 512MiB
parted ${DISK} -- set 1 esp on
parted ${DISK} -- mkpart primary linux-swap 512MiB 2.5GiB
parted ${DISK} -- mkpart primary ext4 2.5GiB 100%

# Format the partitions
mkfs.fat -F32 ${DISK}1
mkswap ${DISK}2
mkfs.ext4 ${DISK}3

# Mount the file systems
mount ${DISK}3 /mnt
mkdir /mnt/boot
mount ${DISK}1 /mnt/boot
swapon ${DISK}2

# Install base packages
pacstrap /mnt base linux linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set the time zone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc

# Localization
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network configuration
echo "${HOSTNAME}" > /etc/hostname
cat <<EOL > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    ${HOSTNAME}.localdomain ${HOSTNAME}
EOL

# Install essential packages
pacman -S --noconfirm ${ESSENTIAL_PACKAGES} ${DISPLAY_MANAGER} ${PACKAGES} ${GUI_PACKAGES}

# Enable NetworkManager
systemctl enable NetworkManager

# Create user
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "root:${PASSWORD}" | chpasswd

# Configure sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Install and configure systemd-boot
bootctl --path=/boot install
cat <<EOL > /boot/loader/loader.conf
default arch
timeout 3
console-mode max
editor no
EOL

cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value ${DISK}3) rw
EOL

# Exit chroot
EOF

# Unmount and reboot
umount -R /mnt
swapoff -a
reboot
