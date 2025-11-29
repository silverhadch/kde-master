#!/bin/bash

set -ouex pipefail
log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

error() {
    echo -e "\n\033[1;31mERROR: $1\033[0m\n" >&2
}

### --------------------
### Generic installer helper
### --------------------
install_group() {
    local title="$1"; shift
    local pkgs=("$@")

    log "Installing $title..."
    for pkg in "${pkgs[@]}"; do
        if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$pkg" 2>/tmp/dnf-error; then
            error "Failed to install $pkg: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
        fi
    done
}

### --------------------
### KDE / Qt / PipeWire development
### --------------------
kde_devel_pkgs=(
    # KDE frameworks & general Plasma dev headers
    aurorae-devel
    krdp-devel
    kpipewire-devel
    pipewire-devel
    plasma-wayland-protocols-devel
    kf6-*-devel
    kdecoration-devel
    kde-*-devel
    kwayland-devel

    # KF6 CMake deps
    "cmake(KF6Config)"
    "cmake(KF6CoreAddons)"
    "cmake(KF6Crash)"
    "cmake(KF6DBusAddons)"
    "cmake(KF6GuiAddons)"
    "cmake(KF6I18n)"
    "cmake(KF6KCMUtils)"
    "cmake(KF6StatusNotifierItem)"

    # Qt6 CMake deps
    "cmake(Qt6Core)"
    "cmake(Qt6DBus)"
    "cmake(Qt6Gui)"
    "cmake(Qt6Network)"
    "cmake(Qt6Qml)"
    "cmake(Qt6Quick)"
    "cmake(Qt6WaylandClient)"

    qt6-qtbase-private-devel

    # FreeRDP stack
    libwinpr-devel
    "cmake(FreeRDP-Server)>=3"
    "cmake(FreeRDP)>=3"
    "cmake(WinPR)>=3"

    # Extra KDE/Wayland components
    "cmake(KPipeWire)"
    "cmake(PlasmaWaylandProtocols)"
    "cmake(Qca)"
    "cmake(Qt6Keychain)"

    # pkgconfig deps
    "pkgconfig(epoxy)"
    "pkgconfig(gbm)"
    "pkgconfig(libdrm)"
    "pkgconfig(libpipewire-0.3)"
    "pkgconfig(libavcodec)"
    "pkgconfig(libavfilter)"
    "pkgconfig(libavformat)"
    "pkgconfig(libavutil)"
    "pkgconfig(libswscale)"
    "pkgconfig(libva-drm)"
    "pkgconfig(libva)"
    "pkgconfig(xkbcommon)"

    # System deps
    pam-devel
    wayland-devel
)

### Install packages
dnf5 group install -y development-tools
dnf5 install -y \
    git ninja-build rsync cargo ccache \
    python3-dbus python3-pyyaml python3-setproctitle python3-requests rust \
    cargo
dnf5 install -y "kf6-*-devel" "kde-*-devel"

install_group "KDE/Qt/PipeWire deps"    "${kde_devel_pkgs[@]}"

### --------------------
### KDE dependency list
### --------------------
log "Fetching KDE metadata deps..."
kde_deps=$(curl -s "https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini" | sed '1d' | grep -vE '^\s*#|^\s*$')

if [[ -n "$kde_deps" ]]; then
    log "Installing KDE metadata deps..."
    echo "$kde_deps" | xargs dnf5 install -y --skip-broken --skip-unavailable --allowerasing 2>/tmp/dnf-error || \
        error "Some KDE deps failed: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
else
    error "Failed to fetch KDE dependency metadata"
fi

### 🔧 KDE Build Dependencies
rm -rf /root
mkdir -p /root
mkdir -p /usr/kde-master/
cp /ctx/kde-builder.yaml /usr/kde-master/kde-builder.yaml
cp /ctx/kde-builder-session-guard.sh /usr/bin/
cp /ctx/kde-builder-session.service /etc/systemd/system/
cd ~
export PATH="$HOME/.local/bin:$PATH"
curl 'https://invent.kde.org/sdk/kde-builder/-/raw/master/scripts/initial_setup.sh' > initial_setup.sh
bash initial_setup.sh
kde-builder --generate-config
kde-builder --install-distro-packages --prompt-answer Y

curl https://storage.kde.org/kde-linux-packages/testing/ccache/ccache.tar | tar -x || true
# Unclear which ccache.conf gets used :(
ccache --set-config=max_size=50G # Sets /root/.config/ccache/ccache.conf
export CCACHE_DIR="$HOME/ccache"
ccache --set-config=max_size=50G # Sets $CCACHE_DIR/ccache.conf


kde-builder workspace --rc-file /usr/kde-master/kde-builder.yaml || {
    for LOGROOT in ~/kde/log/* /root/.local/state/log/*; do
        [ -d "$LOGROOT" ] || continue
        echo "=== Dumping logs from $LOGROOT ==="
        find "$LOGROOT" -type f | sort | while read -r f; do
            echo
            echo "===== $f ====="
            cat "$f"
        done
    done
}

cd /

rm -rf /root
mkdir -p /root

### --------------------
### kde-builder install
### --------------------
log "Installing kde-builder..."
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
git clone https://invent.kde.org/sdk/kde-builder.git
cd kde-builder
install -d /usr/share/kde-builder
cp -r ./* /usr/share/kde-builder
ln -sf /usr/share/kde-builder/kde-builder /usr/bin/kde-builder

install -d /usr/share/zsh/site-functions
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder /usr/share/zsh/site-functions/
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder_projects_and_groups /usr/share/zsh/site-functions/
popd >/dev/null
rm -rf "$tmpdir"

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
systemctl enable sddm.service
systemctl enable kde-builder-session.service
