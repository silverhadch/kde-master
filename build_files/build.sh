#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 groupinstall -y "Development Tools"

dnf5 install -y \
    sddm git ninja-build rsync cargo ccache \
    python3-dbus python3-pyyaml python3-setproctitle python3-requests

### 🔧 KDE Build Dependencies
rm -rf /root
mkdir -p /root
mkdir -p /etc/kde-build
cp /ctx/kde-builder.yaml /etc/kde-build/kde-builder.yaml
cat /etc/kde-build/kde-builder.yaml
cd ~
export PATH="$HOME/.local/bin:$PATH"
curl 'https://invent.kde.org/sdk/kde-builder/-/raw/master/scripts/initial_setup.sh' > initial_setup.sh
bash initial_setup.sh
kde-builder --generate-config
kde-builder --install-distro-packages --prompt-answer Y

DESTDIR=/usr kde-builder workspace --rc-file /etc/kde-build/kde-builder.yaml || true

cd /

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
systemctl enable sddm.service
