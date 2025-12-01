#!/bin/bash

# Exit on unset variables (u), errors (e), and failures in pipes (pipefail).
# Also echo commands (x) for debugging.
set -ouex pipefail

# Colorized logger for status output.
log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

# Colorized logger for errors, goes to stderr.
error() {
    echo -e "\n\033[1;31mERROR: $1\033[0m\n" >&2
}

### --------------------
### Generic installer helper
### --------------------
# install_group "Title" pkg1 pkg2 pkg3...
# Installs each package individually via DNF, catching errors.
install_group() {
    local title="$1"; shift
    local pkgs=("$@")

    log "Installing $title..."
    for pkg in "${pkgs[@]}"; do
        # Install each package with --skip-broken and --skip-unavailable
        # so missing deps don’t abort the entire group.
        if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$pkg" 2>/tmp/dnf-error; then
            # Show trimmed error output.
            error "Failed to install $pkg: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
        fi
    done
}

### --------------------
### KDE / Qt / PipeWire development
### --------------------
# This huge array defines KDE, Qt, Wayland, PipeWire and misc dev packages.
kde_devel_pkgs=(
    # KDE frameworks and Plasma dev headers
    aurorae-devel
    krdp-devel
    kpipewire-devel
    pipewire-devel
    plasma-wayland-protocols-devel
    kf6-*-devel
    kdecoration-devel
    kde-*-devel
    kwayland-devel
    qca-devel
    qca-qt6-devel

    # CMake "find_package" entries for KF6 components
    "cmake(KF6Config)"
    "cmake(KF6CoreAddons)"
    "cmake(KF6Crash)"
    "cmake(KF6DBusAddons)"
    "cmake(KF6GuiAddons)"
    "cmake(KF6I18n)"
    "cmake(KF6KCMUtils)"
    "cmake(KF6StatusNotifierItem)"

    # Qt6 find_package modules
    "cmake(Qt6Core)"
    "cmake(Qt6DBus)"
    "cmake(Qt6Gui)"
    "cmake(Qt6Network)"
    "cmake(Qt6Qml)"
    "cmake(Qt6Quick)"
    "cmake(Qt6WaylandClient)"

    # Qt6 private dev headers (necessary for some Plasma components)
    qt6-qtbase-private-devel

    # FreeRDP development stack
    libwinpr-devel
    "cmake(FreeRDP-Server)>=3"
    "cmake(FreeRDP)>=3"
    "cmake(WinPR)>=3"

    # Additional KDE/Wayland components
    "cmake(KPipeWire)"
    "cmake(PlasmaWaylandProtocols)"
    "cmake(Qca)"
    "cmake(Qt6Keychain)"

    # pkgconfig build deps
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

    # System deps for Plasma builds
    pam-devel
    wayland-devel
)

### Install development tools
dnf5 group install -y development-tools

# Core dev utilities: git, ninja, ccache, rsync, Rust, Python libs, docbook styles, etc.
dnf5 install -y \
    git ninja-build rsync cargo ccache \
    python3-dbus python3-pyyaml python3-setproctitle python3-requests rust \
    cargo docbook-style-xsl

# Install all build-time dependencies for plasma-desktop package
dnf5 builddep plasma-desktop -y

# Wildcard install of KDE and KF6 devel packages
dnf5 install -y "kf6-*-devel" "kde-*-devel"

# Install all previously defined KDE/Wayland/PipeWire dev dependencies
install_group "KDE/Qt/PipeWire deps" "${kde_devel_pkgs[@]}"

### --------------------
### KDE dependency list (from KDE repo metadata)
### --------------------
log "Fetching KDE metadata deps..."

# Download Fedora-specific KDE dependency list.
# Skip first line and remove blanks and comments.
kde_deps=$(curl -s "https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini" | sed '1d' | grep -vE '^\s*#|^\s*$')

# Install those deps if successfully retrieved.
if [[ -n "$kde_deps" ]]; then
    log "Installing KDE metadata deps..."
    echo "$kde_deps" | xargs dnf5 install -y --skip-broken --skip-unavailable --allowerasing 2>/tmp/dnf-error || \
        error "Some KDE deps failed: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
else
    error "Failed to fetch KDE dependency metadata"
fi

### --------------------
### KDE build environment setup
### --------------------

# Nukes /root (sometimes used as a previous build workspace) to ensure a clean state.
rm -rf /root
mkdir -p /root
mkdir -p /usr/kde/
cp /ctx/kde-builder.yaml /usr/kde/kde-builder.yaml
cp /ctx/kde-builder-session-guard.sh /usr/bin/
cp /ctx/kde-builder-session.service /etc/systemd/system/
cd ~

# Prepare root’s config directory.
mkdir -p /root/.config

# Install kde-builder.yaml from build context into root’s config dir.
cp /ctx/kde-builder.yaml /root/.config/kde-builder.yaml

# Go to home directory (~ for root in container is /root)
cd ~

# Put ~/.local/bin in PATH so kde-builder's installed scripts work.
export PATH="$HOME/.local/bin:$PATH"

# Download the kde-builder initial setup script.
curl 'https://invent.kde.org/sdk/kde-builder/-/raw/master/scripts/initial_setup.sh' > initial_setup.sh

# Run it. This bootstraps Python venv and kde-builder tooling.
bash initial_setup.sh

# Download KDE’s ccache bundle to speed up huge rebuilds.
curl https://storage.kde.org/kde-linux-packages/testing/ccache/ccache.tar | tar -x || true

# Set ccache size in two potential config locations.
ccache --set-config=max_size=50G
export CCACHE_DIR="$HOME/ccache"
ccache --set-config=max_size=50G

# Run kde-builder to build the entire Plasma workspace.
kde-builder workspace || {
    # Dump the newest 5 KDE build log directories, not everything.
    log "Build failed — dumping latest logs…"

    # Combine both potential log roots
    for LOGROOT in ~/kde/log; do
        [ -d "$LOGROOT" ] || continue

        # Get newest 5 directories
        mapfile -t recent_dirs < <(find "$LOGROOT" -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\n' \
                                   | sort -nr \
                                   | head -n 5 \
                                   | awk '{print $2}')

        for dir in "${recent_dirs[@]}"; do
            echo "=== Dumping logs from $dir ==="
            # Dump all files inside that dir
            find "$dir" -type f | sort | while read -r f; do
                echo
                echo "===== $f ====="
                cat "$f"
            done
        done
    done
}

# Install the built Plasma into the actual filesystem.
cd /
log "Installing built from source Plasma..."
ls /root/kde

# Reset /root to avoid leftover garbage.
rm -rf /root
mkdir -p /root

### --------------------
### Install kde-builder system-wide
### --------------------
log "Installing kde-builder..."

# Temporary directory to clone kde-builder.
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null

# Clone from KDE Git
git clone https://invent.kde.org/sdk/kde-builder.git
cd kde-builder

# Install the whole repo under /usr/share
install -d /usr/share/kde-builder
cp -r ./* /usr/share/kde-builder

# Create the main /usr/bin/kde-builder executable symlink
ln -sf /usr/share/kde-builder/kde-builder /usr/bin/kde-builder

# Install Zsh completions
install -d /usr/share/zsh/site-functions
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder /usr/share/zsh/site-functions/
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder_projects_and_groups /usr/share/zsh/site-functions/

popd >/dev/null
rm -rf "$tmpdir"

# Example COPR enabling (commented out)
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# dnf5 -y copr disable ublue-os/staging

# Example unit files to enable
systemctl enable podman.socket
systemctl enable sddm.service
systemctl enable kde-builder-session.service
