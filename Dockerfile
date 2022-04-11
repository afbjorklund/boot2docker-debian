FROM debian:bullseye

# Work around initramfs-tools running on kernel 'upgrade': <http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=594189>
RUN mkdir -p /etc/container_environment && echo -n "no" > /etc/container_environment/INITRD
RUN mkdir -p /etc/initramfs-tools/conf.d && echo "RESUME=none" > /etc/initramfs-tools/conf.d/resume

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		acpi-support-base \
		bash-completion \
		busybox \
		ca-certificates \
		linux-image-generic \
		systemd-timesyncd \
		openssh-server \
		rsync \
		sudo \
		systemd-sysv \
		\
		squashfs-tools \
		xorriso \
		xz-utils \
		\
		grub-efi \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /etc/ssh/ssh_host_* \
	&& mkdir -p /tmp/iso

#		curl \
#		wget \

# BUSYBOX ALL UP IN HERE
RUN set -e \
	&& busybox="$(which busybox)" \
	&& for m in $("$busybox" --list); do \
		if ! command -v "$m" > /dev/null; then \
			ln -vL "$busybox" /usr/local/bin/"$m"; \
		fi; \
	done

# if /etc/machine-id is empty, systemd will generate a suitable ID on boot
RUN echo -n > /etc/machine-id

# setup networking (hack hack hack)
RUN systemctl enable systemd-networkd
RUN for iface in eth0 eth1 eth2 eth3; do \
		{ \
			echo "[Match]"; \
			echo "Name=$iface"; \
			echo; \
			echo "[Network]"; \
			echo "DHCP=yes"; \
		} > /etc/systemd/network/80-$iface.network; \
	done

# COLOR PROMPT BABY
RUN sed -ri 's/^#(force_color_prompt=)/\1/' /etc/skel/.bashrc \
	&& cp /etc/skel/.bashrc /root/

# setup our non-root user, set passwords for both users, and setup sudo
RUN useradd --create-home --shell /bin/bash docker \
	&& { \
		echo 'root:docker'; \
		echo 'docker:docker'; \
	} | chpasswd \
	&& echo 'docker ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/docker

# autologin for all tty
# see also: grep ^ExecStart /lib/systemd/system/*getty@.service
RUN mkdir -p /etc/systemd/system/getty@.service.d && { \
		echo '[Service]'; \
		echo 'ExecStart='; \
		echo 'ExecStart=-/sbin/agetty --autologin docker --noclear %I $TERM'; \
	} > /etc/systemd/system/getty@.service.d/autologin.conf
RUN mkdir -p /etc/systemd/system/serial-getty@.service.d && { \
		echo '[Service]'; \
		echo 'ExecStart='; \
		echo 'ExecStart=-/sbin/agetty --autologin docker --keep-baud 115200,38400,9600 %I $TERM'; \
	} > /etc/systemd/system/serial-getty@.service.d/autologin.conf


# setup NTP to use the boot2docker vendor pool instead of Debian's
RUN systemctl enable systemd-timesyncd
RUN echo 'NTP=boot2docker.pool.ntp.org' >> /etc/systemd/timesyncd.conf

# set a default LANG (sshd reads from here)
# this prevents warnings later
RUN echo 'LANG=C.UTF-8' > /etc/default/locale

# PURE VANITY
RUN { echo; echo 'Docker (\\s \\m \\r) [\\l]'; echo; } > /etc/issue
RUN . /etc/os-release && echo "$PRETTY_NAME" > /tmp/iso/version

COPY scripts/generate-ssh-host-keys.sh /usr/local/sbin/
COPY inits/ssh-keygen /etc/init.d/
RUN update-rc.d ssh-keygen defaults

COPY scripts/initramfs-live-hook.sh /usr/share/initramfs-tools/hooks/live
COPY scripts/initramfs-live-script.sh /usr/share/initramfs-tools/scripts/live

COPY excludes /tmp/
COPY scripts/audit-rootfs.sh scripts/build-rootfs.sh scripts/build-iso.sh /usr/local/sbin/

RUN apt-get update \
	&& apt-get install -y --no-install-recommends dosfstools mtools \
	&& rm -rf /var/lib/apt/lists/*
COPY scripts/build-iso-efi.sh /usr/local/sbin/
COPY scripts/build-iso-grub.sh /usr/local/sbin/build-iso.sh

#RUN build-iso.sh # creates /tmp/docker.iso
