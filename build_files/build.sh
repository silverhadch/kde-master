#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y sddm

### 🔧 KDE Build Dependencies
log "Installing KDE"

cd ~
curl 'https://invent.kde.org/sdk/kde-builder/-/raw/master/scripts/initial_setup.sh' > initial_setup.sh
bash initial_setup.sh
kde-builder --generate-config
kde-builder --install-distro-packages
FILE=~/.config/kde-builder.yaml

# Ensure install-dir: /usr/
grep -q '^install-dir:' "$FILE" \
  && sed -i 's|^install-dir:.*|install-dir: /usr/|' "$FILE" \
  || echo 'install-dir: /usr/' >> "$FILE"

# Desired cmake-options line (YAML folded block style)
CMAKE_OPTIONS='cmake-options: >
    -DCMAKE_BUILD_TYPE=RelWithDebInfo -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DBUILD_HTML_DOCS=OFF -DBUILD_MAN_DOCS=OFF -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_C_LINKER_LAUNCHER=ccache -DCMAKE_CXX_LINKER_LAUNCHER=ccache'

# Replace or add cmake-options block
if grep -q '^cmake-options:' "$FILE"; then
  # Replace the cmake-options block (assuming it's a folded block starting with '>')
  sed -i '/^cmake-options: *>/,/^[^ ]/c\'"$CMAKE_OPTIONS" "$FILE"
else
  echo "$CMAKE_OPTIONS" >> "$FILE"
fi

kde-builder workspace



# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
systemctl enable sddm.service
