#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export DEBIAN_FRONTEND=noninteractive

echo "==> Waiting for apt lock (unattended-upgrades may be running)..."
apt-get -o DPkg::Lock::Timeout=120 update -qq
apt-get -o DPkg::Lock::Timeout=120 upgrade -y -qq > /dev/null
apt-get -o DPkg::Lock::Timeout=120 install -y -qq libstdc++6 ufw p7zip-full jq lbzip2 > /dev/null

echo "==> Downloading UT99 installer..."
cd /tmp
curl -fsSL -o install-ut99.sh \
    "https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut99.sh"
chmod +x install-ut99.sh

echo "==> Installing UT99..."
echo "yes" | ./install-ut99.sh --destination /opt/ut99 --ui-mode none \
    --application-entry skip --desktop-shortcut skip

echo "==> Creating ut99 user..."
useradd --system --shell /usr/sbin/nologin --home-dir /opt/ut99 ut99 || true
chown -R ut99:ut99 /opt/ut99

download_from_space() {
    local space_url="$1" folder="$2" dest="$3"
    local listing keys
    listing=$(curl -fsSL "${space_url}?prefix=${folder}/")
    keys=$(echo "$listing" | grep -oP "<Key>${folder}/[^<]+</Key>" | sed "s/<Key>${folder}\///;s/<\/Key>//" || true)
    [[ -n "$keys" ]] || return 0
    echo "==> Downloading ${folder} from DO Space..."
    for key in $keys; do
        echo "    Downloading $key..."
        curl -fsSL -o "${dest}/${key}" "${space_url}/${folder}/${key}"
    done
    chown -R ut99:ut99 "$dest"
}

if [[ -n "${1:-}" ]]; then
    download_from_space "$1" "maps" "/opt/ut99/Maps"
    download_from_space "$1" "plugins" "/opt/ut99/System"
fi

echo "==> Configuring server..."
INI="/opt/ut99/System64/UnrealTournament.ini"

sed -i 's/^CacheSizeMegs=.*/CacheSizeMegs=64/' "$INI"
sed -i 's/^NetServerMaxTickRate=.*/NetServerMaxTickRate=35/' "$INI"
sed -i 's/^MaxClientRate=.*/MaxClientRate=15000/' "$INI"
sed -i 's/^UseCompression=.*/UseCompression=True/' "$INI"
sed -i 's/^AllowDownloads=.*/AllowDownloads=True/' "$INI"
sed -i 's/^ServerName=.*/ServerName=UT99 Server/' "$INI"
sed -i 's/^MinPlayers=.*/MinPlayers=2/' "$INI"

echo "==> Configuring bot difficulty..."
sed -i 's/^Difficulty=.*/Difficulty=0/' /opt/ut99/System64/User.ini

echo "==> Installing systemd service..."
cp "$SCRIPT_DIR/ut99.service" /etc/systemd/system/ut99.service
systemctl daemon-reload

echo "==> Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 7777:7779/udp
ufw --force enable

echo "==> Installing set-maps.sh helper..."
cp "$SCRIPT_DIR/set-maps.sh" /opt/ut99/set-maps.sh
chmod +x /opt/ut99/set-maps.sh

echo "==> Starting UT99 server..."
systemctl enable ut99
systemctl start ut99

echo "==> Provisioning complete"
