#!/bin/bash
set -euo pipefail

check_dir() {
    local dir="$1"
    local files=("$dir"/*.desktop)

    [[ ! -e "${files[0]}" ]] && return 0

    for file in "${files[@]}"; do
        if grep -q "^DesktopNames=.*KDE" "$file"; then
            if ! grep -q "^Exec=.*/usr/kde/" "$file"; then
                echo "Detected locally overridden Plasma session in $file"
                return 1
            fi
        fi
    done
}

if check_dir /usr/local/share/wayland-sessions \
   && check_dir /usr/local/share/xsessions; then
    echo "No override found. Running kde-builder..."
    kde-builder --install-login-session-only --rc-file /usr/kde/kde-builder.yaml
else
    echo "Override detected. Not touching user session."
fi

