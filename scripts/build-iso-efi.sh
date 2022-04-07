#!/bin/bash
set -e

BOOT_IMG_DATA=$(mktemp -d)
BOOT_IMG=$(mktemp -d)/efi.img

mkdir -p $(dirname $BOOT_IMG)

truncate -s 8M $BOOT_IMG
mkfs.vfat $BOOT_IMG
#mount $BOOT_IMG $BOOT_IMG_DATA
mkdir -p $BOOT_IMG_DATA/efi/boot

cp /tmp/iso/boot/grub/grub.cfg $BOOT_IMG_DATA/efi/boot

case $(uname -m) in
x86_64)
grub-mkimage \
    -C xz \
    -O x86_64-efi \
    -p /boot/grub \
    -o $BOOT_IMG_DATA/efi/boot/bootx64.efi \
    boot linux search normal configfile \
    part_gpt btrfs ext2 fat iso9660 loopback \
    test keystatus gfxmenu regexp probe \
    efi_gop efi_uga all_video gfxterm font \
    echo read ls cat png jpeg halt reboot
;;
aarch64)
grub-mkimage \
    -C xz \
    -O arm64-efi \
    -p /boot/grub \
    -o $BOOT_IMG_DATA/efi/boot/bootaa64.efi \
    boot linux search normal configfile \
    part_gpt btrfs ext2 fat iso9660 loopback \
    test keystatus gfxmenu regexp probe \
    efi_gop all_video gfxterm font \
    echo read ls cat png jpeg halt reboot
;;
esac

#umount $BOOT_IMG_DATA
cd $BOOT_IMG_DATA
mcopy -s -i $BOOT_IMG efi ::
cd -
rm -rf $BOOT_IMG_DATA

mkdir -p /tmp/iso/boot/grub
cp $BOOT_IMG /tmp/iso/boot/grub/efi.img
