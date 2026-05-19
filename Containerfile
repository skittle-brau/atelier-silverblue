# Use the official Fedora Silverblue (GNOME) base image
FROM quay.io/fedora-ostree-desktops/silverblue:44

# Install RPM Fusion Free and Nonfree repositories directly
RUN dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm

# Install packages

## ROCm and HIP
RUN dnf5 install -y \
    rocm-hip \
    rocm-opencl \
    rocm-clinfo \
    && dnf5 clean all

## Development & System Tools
RUN dnf5 install -y \
    distrobox \
    gcc \
    gnome-disk-utility \
    && dnf5 clean all

## Gaming
RUN dnf5 install -y \
    steam \
    steam-devices \
    && dnf5 clean all

# Comprehensive AMD/Mesa 32-bit & 64-bit hardware drivers
RUN dnf5 install -y \
    mesa-vulkan-drivers \
    mesa-vulkan-drivers.i686 \
    mesa-dri-drivers \
    mesa-dri-drivers.i686 \
    mesa-libGL \
    mesa-libGL.i686 \
    mesa-libEGL \
    mesa-libEGL.i686 \
    mesa-va-drivers \
    mesa-va-drivers.i686 && \
    dnf5 clean all

## Virtualisation Stack
RUN dnf5 install -y \
    virt-manager \
    libvirt \
    libvirt-client \
    virt-install \
    virt-viewer \
    qemu-kvm \
    && dnf5 clean all

# Enable the Cisco OpenH264 repo
RUN sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/fedora-cisco-openh264.repo

# Swap to Full Codecs and FFmpeg
RUN dnf5 -y update && \
    dnf5 install -y --allowerasing --best \
        ffmpeg \
        compat-ffmpeg4 \
        intel-media-driver \
        gstreamer1-plugin-libav \
        gstreamer1-plugins-bad-free-extras \
        gstreamer1-plugins-bad-freeworld \
        gstreamer1-plugins-ugly \
        gstreamer1-vaapi \
        libavcodec-freeworld && \
    dnf5 clean all

# Preinstall flatpak applications
COPY flatpak-apps.preinstall /usr/share/flatpak/preinstall.d/

# 1Password
## Add 1Password repository and GPG key
RUN rpm --import https://downloads.1password.com/linux/keys/1password.asc && \
    printf "[1password]\n\
name=1Password Stable Channel\n\
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\n\
enabled=1\n\
gpgcheck=1\n\
repo_gpgcheck=1\n\
gpgkey=https://downloads.1password.com/linux/keys/1password.asc\n" > /etc/yum.repos.d/1password.repo

# Workaround for /opt
RUN mkdir -p /usr/lib/1Password && \
    rm -f /opt && \
    mkdir -p /opt && \
    ln -sf /usr/lib/1Password /opt/1Password

# Install 1Password, 1Password CLI, and other custom packages
RUN dnf5 install -y \
    1password \
    1password-cli \
    && rm -f /etc/yum.repos.d/1password.repo \
    && dnf5 clean all

## Tell systemd to recreate the /var/opt/1Password symlink on boot (using tmpfiles.d)
RUN mkdir -p /usr/lib/tmpfiles.d && \
    echo "L /var/opt/1Password - - - - /usr/lib/1Password" > /usr/lib/tmpfiles.d/1password.conf

## Install Polkit Policy (using the template provided by the 1Password install)
RUN mkdir -p /usr/share/polkit-1/actions && \
    sed "s/{{POLICY_OWNERS}}/unix-user:root/g" \
    /usr/lib/1Password/com.1password.1Password.policy.tpl \
    > /usr/share/polkit-1/actions/com.1password.1Password.policy

## Install custom allowed browsers configuration
RUN install -Dm0644 /usr/lib/1Password/resources/custom_allowed_browsers -t /etc/1password/

## Set chrome-sandbox setuid permissions
RUN chmod 4755 /usr/lib/1Password/chrome-sandbox

## Create standard binary symlink
RUN ln -sf /usr/lib/1Password/1password /usr/bin/1password

## Configure Browser Native Messaging (Firefox/Chrome integration)
RUN mkdir -p /usr/lib/mozilla/native-messaging-hosts && \
    printf '{\n\
  "name": "com.1password.1password",\n\
  "description": "1Password BrowserSupport",\n\
  "path": "/usr/lib/1Password/1Password-BrowserSupport",\n\
  "type": "stdio",\n\
  "allowed_extensions": [\n\
    "{0a75d802-9aed-41e7-8daa-24c067386e82}",\n\
    "{25fc87fa-4d31-4fee-b5c1-c32a7844c063}",\n\
    "{d634138d-c276-4fc8-924b-40a0ea21d284}"\n\
  ]\n\
}\n' > /usr/lib/mozilla/native-messaging-hosts/com.1password.1password.json && \
    mkdir -p /usr/lib64/mozilla/native-messaging-hosts && \
    cp /usr/lib/mozilla/native-messaging-hosts/com.1password.1password.json \
       /usr/lib64/mozilla/native-messaging-hosts/com.1password.1password.json

## Define system groups & apply strict GIDs and permissions
RUN mkdir -p /usr/lib/sysusers.d && \
    printf "g onepassword     1500\ng onepassword-cli 1600\n" > /usr/lib/sysusers.d/onepassword.conf && \
    chgrp 1500 /usr/lib/1Password/1Password-BrowserSupport && \
    chmod g+s /usr/lib/1Password/1Password-BrowserSupport && \
    chgrp 1600 /usr/bin/op && \
    chmod g+s /usr/bin/op

## Complete clean-up of /var state to guarantee "bootc lint" passes
RUN rm -rf /var/lib/dnf /var/cache/dnf /var/log/dnf* /var/opt/1Password

# Copy system configurations directly to /etc or /usr
# Example: Adding a custom policy or configuration file
# COPY custom-policy.json /etc/containers/policy.json

# If you need to enable systemd services, do it here
#RUN systemctl enable tailscaled.service || true
