#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 ]] || { echo "Usage: set-maps.sh MAP1 [MAP2 ...]" >&2; exit 1; }

MAPS_DIR="/opt/ut99/Maps"
INI="/opt/ut99/System64/UnrealTournament.ini"
SERVICE="/etc/systemd/system/ut99.service"

# Validate all maps exist (case-insensitive)
for map in "$@"; do
    found=false
    for f in "$MAPS_DIR"/*.unr; do
        basename=$(basename "$f" .unr)
        if [[ "${basename,,}" == "${map,,}" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == "false" ]]; then
        echo "error: map '$map' not found in $MAPS_DIR" >&2
        exit 1
    fi
done

# Rewrite MapList entries in [Botpack.DeathMatchPlus] section
tmpfile=$(mktemp)
in_section=false
section_done=false

inject_maps() {
    local_index=0
    for map in "$@"; do
        echo "MapList[$local_index]=$map"
        ((local_index += 1))
    done
    echo "MapListCount=$#"
}

{
    while IFS= read -r line; do
        if [[ "$line" == "[Botpack.DeathMatchPlus]" ]]; then
            in_section=true
            echo "$line"
            continue
        fi

        if $in_section && ! $section_done; then
            # Skip existing MapList and MapListCount lines anywhere in the section
            if [[ "$line" =~ ^MapList\[ ]] || [[ "$line" =~ ^MapListCount= ]]; then
                continue
            fi

            # New section header means we're leaving — inject before it
            if [[ "$line" =~ ^\[.+\] ]]; then
                inject_maps "$@"
                section_done=true
                echo "$line"
                continue
            fi

            # Pass through all other lines in the section
            echo "$line"
            continue
        fi

        echo "$line"
    done

    # Handle case where section runs to EOF without another section header
    if $in_section && ! $section_done; then
        inject_maps "$@"
    fi
} < "$INI" > "$tmpfile"

mv "$tmpfile" "$INI"
chown ut99:ut99 "$INI"

# Update systemd ExecStart to use first map
sed -i "s|^\(ExecStart=/opt/ut99/System64/ucc-bin server \)[^ ?]*|\1$1|" "$SERVICE"

systemctl daemon-reload
systemctl restart ut99

echo "Map rotation set to: $*"
