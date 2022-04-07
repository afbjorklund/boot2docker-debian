#!/bin/bash
set -e

mkdir -p /tmp/iso/boot/grub

cat > /tmp/iso/boot/grub/grub.cfg <<EOH
# title-text $(head -1 /tmp/iso/version)
set timeout=2
EOH

case $(uname -m) in
x86_64)
	commonAppend='console=ttyS0 console=tty0 boot=live'
	extraAppend='cgroup_enable=memory swapaccount=1'
	;;
aarch64)
	commonAppend='console=ttyAMA0 console=tty0 boot=live'
	extraAppend='cgroup_enable=memory swapaccount=1'
	;;
esac

# explicitly disable "Predictable Network Interface Names" since it causes troubles with our pre-determined /etc/network/interfaces* (and this fix is much easier than implementing our own auto-scan on boot or including network-manager)
commonAppend+=' net.ifnames=0'

cat >> /tmp/iso/boot/grub/grub.cfg <<EOE

menuentry "Docker" --id docker {
	linux /live/vmlinuz $commonAppend $extraAppend loglevel=3
	initrd /live/initrd.img
}

menuentry "Docker (recovery mode)" --id docker-safe {
	linux /live/vmlinuz $commonAppend single
	initrd /live/initrd.img
}
EOE

build-rootfs.sh

mkdir -p /tmp/iso/live

build-iso-efi.sh

echo >&2 'Updating initrd.img ...'
update-initramfs -k all -u
ln -L /vmlinuz /initrd.img /tmp/iso/live/

# volume IDs must be 32 characters or less
volid="$(head -1 /tmp/iso/version | sed 's/ version / v/')"
if [ ${#volid} -gt 32 ]; then
	volid="$(printf '%-32.32s' "$volid")"
fi

echo >&2 'Building the ISO ...'
xorriso \
	-as mkisofs \
	-A 'Docker' \
	-V "$volid" \
	-l -J -rock -joliet-long \
	-e boot/grub/efi.img \
	-no-emul-boot \
	-o /tmp/docker.iso \
	/tmp/iso

rm -rf /tmp/iso/live /tmp/rootfs.tar.xz
