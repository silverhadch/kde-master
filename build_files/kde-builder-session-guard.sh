#!/bin/bash
set -ouex pipefail

# --------------------
# Guard: refuse to overwrite user session
# --------------------
check_override() {
    local dirs=(
        /usr/local/share/wayland-sessions
        /usr/local/share/xsessions
    )

    for d in "${dirs[@]}"; do
        [ -d "$d" ] || continue

        for f in "$d"/*.desktop; do
            [ -f "$f" ] || continue

            # If the file exists and does NOT contain the canonical session path
            if ! grep -q '/usr/kde-master' "$f"; then
                echo "Detected user session override in: $f"
                echo "Skipping kde-builder login-session installation."
                return 1
            fi
        done
    done

    return 0
}

if check_override; then
    kde-builder --install-login-session-only --rc-file /usr/kde-master/kde-builder.yaml
fi
