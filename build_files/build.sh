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
log "Installing KDE build dependencies (this might take a while)..."
dnf5 install -y --skip-broken \
  LibRaw-devel PackageKit SDL2-devel aha appstream-qt-devel bison boost-devel bzip2 \
  cfitsio-devel chmlib-devel cmake \
  'cmake(kColorPicker-Qt6)' 'cmake(KDcrawQt6)' 'cmake(KF6Baloo)' 'cmake(KF6Crash)' \
  'cmake(KF6DocTools)' 'cmake(KF6GuiAddons)' 'cmake(KF6I18n)' 'cmake(KF6IconThemes)' \
  'cmake(KF6KIO)' 'cmake(KF6ItemModels)' 'cmake(KF6Notifications)' 'cmake(KF6Parts)' \
  'cmake(KF6Purpose)' 'cmake(kImageAnnotator-Qt6)' 'cmake(Phonon4Qt6)' 'cmake(PlasmaActivities)' \
  cyrus-sasl-devel dbusmenu-qt5-devel djvulibre-devel docbook-style-xsl docbook-utils doxygen \
  ebook-tools-devel eigen3-devel erfa-devel exiv2-devel flatpak-builder flatpak-devel flex \
  fuse-devel fuse3-devel gcc gcc-c++ gettext gettext-devel giflib-devel git glew-devel \
  gobject-introspection-devel gperf gpgmepp-devel gsl-devel gstreamer1-plugins-base-devel \
  hunspell hunspell-devel ibus-devel intltool itstool json-c-devel kcolorpicker-devel \
  kdsoap-devel kf5-kdnssd-devel kf5-kplotting-devel kf5-libkdcraw-devel kf6-kio kf6-kio-devel \
  kimageannotator-devel libappstream-glib libXcursor-devel libXext-devel libXft-devel \
  libXtst-devel libXxf86vm-devel libblack-hole-solver-devel libcanberra-devel libcap-devel \
  libdisplay-info-devel libepoxy-devel libfakekey-devel libfreecell-solver-devel libgcrypt-devel \
  libgit2-devel libical-devel libindi-devel libjpeg-turbo-devel libmtp-devel libnl3-devel \
  libnova-devel libpcap-devel libqalculate-devel libsass-devel libsmbclient-devel libsndfile-devel \
  libsodium-devel libspectre-devel libssh-devel libtirpc-devel libuuid-devel libva-devel \
  libwacom-devel libxcvt-devel libxkbcommon-devel libxkbcommon-x11-devel libxkbfile-devel \
  libxml2 libzip-devel libzstd-devel lm_sensors-devel make meson mpv-libs-devel openal-soft-devel \
  openexr-devel openjpeg2-devel pam-devel pcre-devel phonon-qt5-devel pipewire-devel \
  pipewire-utils \
  'pkgconfig(ModemManager)' 'pkgconfig(accounts-qt6)' 'pkgconfig(dbus-1)' \
  'pkgconfig(gbm)' 'pkgconfig(gl)' 'pkgconfig(gstreamer-1.0)' 'pkgconfig(libaccounts-glib)' \
  'pkgconfig(libassuan)' 'pkgconfig(libattr)' 'pkgconfig(libavcodec)' 'pkgconfig(libavfilter)' \
  'pkgconfig(libavformat)' 'pkgconfig(libavutil)' 'pkgconfig(libnm)' 'pkgconfig(libpng)' \
  'pkgconfig(libproxy-1.0)' 'pkgconfig(libqrencode)' 'pkgconfig(libswscale)' 'pkgconfig(libvlc)' \
  'pkgconfig(libxml-2.0)' 'pkgconfig(libxslt)' 'pkgconfig(lmdb)' 'pkgconfig(openssl)' \
  'pkgconfig(polkit-gobject-1)' 'pkgconfig(sm)' 'pkgconfig(wayland-client)' \
  'pkgconfig(wayland-protocols)' 'pkgconfig(xapian-core)' 'pkgconfig(xcb-cursor)' \
  'pkgconfig(xcb-ewmh)' 'pkgconfig(xcb-keysyms)' 'pkgconfig(xcb-util)' 'pkgconfig(xfixes)' \
  'pkgconfig(xrender)' plymouth-devel plasma-discover pyside6-tools python python3-psutil \
  python3-setuptools python3-sphinx \
  'python3dist(sphinxcontrib-qthelp)' 'qaccessibilityclient-*devel' qcoro-qt5-devel qgpgme-devel \
  'qt5-*-devel' qt5-qtbase-static qt5-qttools-static 'qt6-*-devel' qtkeychain-qt5-devel sassc \
  shared-mime-info shiboken6 signon-devel shadow-utils shadow-utils-subid-devel \
  stellarsolver-devel systemd-devel texinfo wcslib-devel xdotool xkeyboard-config-devel xmlto \
  xorg-x11-drv-evdev-devel xorg-x11-drv-libinput-devel xorg-x11-drv-wacom-devel expat-devel \
  libcurl-devel nss-devel gi-docgen guidelines-support-library-devel libstemmer-devel libyaml-devel \
  'pkgconfig(librsvg-2.0)' 'pkgconfig(libgphoto2)' opencv-devel zxing-cpp-devel ostree-devel \
  cdparanoia-devel 'pkgconfig(xt)' freerdp freerdp-devel 'cmake(ryml)' libmpc-devel \
  'python3dist(build)' clang

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
