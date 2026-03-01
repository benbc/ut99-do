#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: set-maps.sh MAP1 [MAP2 ...]" >&2; exit 1; }

MAPS_DIR="/opt/ut99/Maps"
UNUSED_DIR="$MAPS_DIR/unused"
INI="/opt/ut99/System64/UnrealTournament.ini"
SERVICE="/etc/systemd/system/ut99.service"

# Validate all maps exist in unused/ (case-insensitive)
for map in "$@"; do
    found=false
    for f in "$UNUSED_DIR"/*.unr; do
        basename=$(basename "$f" .unr)
        if [[ "${basename,,}" == "${map,,}" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == "false" ]]; then
        echo "error: map '$map' not found in $UNUSED_DIR" >&2
        exit 1
    fi
done

echo "==> Stopping UT99 server..."
systemctl stop ut99

echo "==> Updating maps..."
rm -f "$MAPS_DIR"/*.unr
for map in "$@"; do
    cp "$UNUSED_DIR"/"$map".unr "$MAPS_DIR"/
done
chown ut99:ut99 "$MAPS_DIR"/*.unr

echo "==> Updating map rotation..."

# Remove any existing [Botpack.TDMmaplist] section (truncate from that header onward)
if grep -qn '^\[Botpack\.TDMmaplist\]' "$INI"; then
    line_num=$(grep -n '^\[Botpack\.TDMmaplist\]' "$INI" | head -1 | cut -d: -f1)
    head -n "$((line_num - 1))" "$INI" > "$INI.tmp"
    mv "$INI.tmp" "$INI"
fi

# Append new map list section
{
    echo "[Botpack.TDMmaplist]"
    index=0
    for map in "$@"; do
        echo "Maps[$index]=$map.unr"
        ((index += 1))
    done
    # Pad with empty entries up to index 4095 to work around a server bug
    while [[ $index -le 4095 ]]; do
        echo "Maps[$index]="
        ((index += 1))
    done
} >> "$INI"

chown ut99:ut99 "$INI"

# Use the last map for ExecStart. UT runs the command-line map first, then proceeds
# through the map list in order. Using the last map avoids seeing it twice on the
# initial rotation.
last_map="${@: -1}"
sed -i "s|^\(ExecStart=/opt/ut99/System64/ucc-bin server \)[^ ?]*|\1$last_map|" "$SERVICE"

systemctl daemon-reload

echo "==> Starting UT99 server..."
systemctl start ut99

echo "Map rotation set to: $*"
