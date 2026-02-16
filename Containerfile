FROM docker.io/library/ubuntu:questing

ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root --mount=type=tmpfs,dst=/boot apt update -y && \
  apt install -y btrfs-progs dosfstools e2fsprogs fdisk linux-firmware linux-image-generic skopeo systemd systemd-boot* xfsprogs && \
  cp /boot/vmlinuz-* "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/vmlinuz" && \
  apt clean -y

# Setup a temporary root passwd (changeme) for dev purposes
# RUN apt update -y && apt install -y whois
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

ENV CARGO_HOME=/tmp/rust
ENV RUSTUP_HOME=/tmp/rust
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root --mount=type=tmpfs,dst=/boot \
    apt update -y && \
    apt install -y git curl make build-essential go-md2man libzstd-dev pkgconf dracut libostree-dev ostree && \
    curl --proto '=https' --tlsv1.2 -sSf "https://sh.rustup.rs" | sh -s -- --profile minimal -y && \
    git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc && \
    sh -c ". ${RUSTUP_HOME}/env ; make -C /tmp/bootc bin install-all" && \
    printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf" && \
    printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf" && \
    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | tail -n 1)/initramfs.img" && \
    apt purge -y git curl make build-essential go-md2man libzstd-dev pkgconf libostree-dev && \
    apt autoremove -y && \
    apt clean -y

# Necessary for general behavior expected by image-based systems
RUN echo "HOME=/var/home" | tee -a "/etc/default/useradd" && \
    rm -rf /boot /home /root /usr/local /srv /var && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var && \
    ln -s sysroot/ostree /ostree && ln -s var/roothome /root && ln -s var/srv /srv && ln -s var/opt /opt && ln -s var/mnt /mnt && ln -s var/home /home && \
    echo "$(for dir in opt home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"

RUN <<_MAIN_INSTALL
    #!/bin/sh -e
    
    # Add repositories
    apt update
    apt install -y software-properties-common
    add-apt-repository ppa:zorinos/stable
    add-apt-repository ppa:zorinos/patches
    add-apt-repository ppa:zorinos/apps
    add-apt-repository ppa:kisak/kisak-mesa
    add-apt-repository multiverse
    add-apt-repository universe
    apt update
    apt-get install -y zorin-os-keyring
    
    # Core deps
    apt install -y --no-install-recommends \
        xwayland \
        libglx-mesa0 libgl1 \
        systemd \
        libnss3 \
        wget \
        curl \
        ca-certificates \
        gnupg2 \
        dbus-x11 \
        dbus-user-session \
        flatpak \
        sudo \
        locales \
        xdg-utils \
        libfreetype6:i386 \
        libvulkan1 \
        libvulkan1:i386 \
        mesa-vulkan-drivers \
        mesa-vulkan-drivers:i386 \
        libasound2-plugins:i386 \
        libsdl2-2.0-0:i386 \
        libdbus-1-3:i386 \
        libsqlite3-0:i386 \
        zenity \
        libnotify4 \
        xdg-utils \
        libsecret-1-0 \
        curl \
        unzip \
        p7zip-full \
        cabextract \
        gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav \
        gstreamer1.0-plugins-base:i386 gstreamer1.0-plugins-good:i386 gstreamer1.0-plugins-bad:i386 gstreamer1.0-plugins-ugly:i386 gstreamer1.0-libav:i386 \
        tar \
        libx11-6 libxext6 libxfixes3 libxdamage1 \
        libxshmfence1 libxxf86vm1 \
        libdrm2 libgbm1 libpixman-1-0 \
        gnome-software-plugin-flatpak \
        ca-certificates \
        xz-utils \
        libgbm1 libgles2 libegl1 libgl1-mesa-dri \
        libnvidia-egl-wayland1 libnvidia-egl-gbm1 \
        steam-installer dbus-daemon dbus-system-bus-common dbus-session-bus-common \
        libxext6 \
        libvulkan-dev \
        vulkan-tools \
        zip unzip p7zip-full \
        gnome-software gnome-software-plugin-flatpak \
        sway zorin-os-desktop zorin-appearance 
    
    # Apt cleanup
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    _MAIN_INSTALL

# https://bootc-dev.github.io/bootc/bootc-images.html#standard-metadata-for-bootc-compatible-images
LABEL containers.bootc 1

RUN bootc container lint
