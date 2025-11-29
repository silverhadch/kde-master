#!/bin/bash
set -euo pipefail

check_dir() {
    local dir="$1"
    local files=("$dir"/*.desktop)

    # Falls das Globbing nichts findet → überspringen
    [[ ! -e "${files[0]}" ]] && return 0

    for file in "${files[@]}"; do
        # Ignoriere Non-Plasma Sessions
        if grep -q "^DesktopNames=.*KDE" "$file"; then
            # Enthält Exec die erwartete /usr/kde-master Basis?
            if ! grep -q "^Exec=.*/usr/kde-master/" "$file"; then
                echo "Detected locally overridden Plasma session in $file"
                return 1
            fi
        fi
    done
}

if check_dir /usr/local/share/wayland-sessions \
   && check_dir /usr/local/share/xsessions; then
    echo "No override found. Running kde-builder..."
    kde-builder --install-login-session-only --rc-file /usr/kde-master/kde-builder.yaml
else
    echo "Override detected. Not touching user session."
fi

