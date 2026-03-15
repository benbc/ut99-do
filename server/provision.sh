#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1

DOMAIN="${2:-}"
WEBADMIN_PASSWORD="${3:-}"
INGAME_ADMIN_PASSWORD="${4:-}"

echo "==> Installing packages..."
apt-get -o DPkg::Lock::Timeout=120 update -qq
apt-get -o DPkg::Lock::Timeout=120 dist-upgrade -y -qq
apt-get -o DPkg::Lock::Timeout=120 install -y -qq libstdc++6 ufw p7zip-full jq lbzip2
apt-get -o DPkg::Lock::Timeout=120 autoremove -y -qq

echo "==> Installing UT99..."
cd /tmp
curl -fsSL -o install-ut99.sh \
    "https://raw.githubusercontent.com/OldUnreal/FullGameInstallers/master/Linux/install-ut99.sh"
chmod +x install-ut99.sh
echo "yes" | ./install-ut99.sh --destination /opt/ut99 --ui-mode none \
    --application-entry skip --desktop-shortcut skip > /dev/null

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
        echo "    $key"
        curl -fsSL -o "${dest}/${key}" "${space_url}/${folder}/${key}"
    done
    chown -R ut99:ut99 "$dest"
}

echo "==> First-run initialization..."
cp "$SCRIPT_DIR/ut99.service" /etc/systemd/system/ut99.service
systemctl daemon-reload
systemctl start ut99
sleep 3
systemctl stop ut99

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
sed -i 's/^FragLimit=.*/FragLimit=10/' "$INI"
sed -i 's/^bMultiWeaponStay=.*/bMultiWeaponStay=False/' "$INI"
sed -i 's/^RestartWait=.*/RestartWait=8/' "$INI"
sed -i 's/^bLocalLog=.*/bLocalLog=False/' "$INI"
sed -i 's/^bWorldLog=.*/bWorldLog=False/' "$INI"
sed -i 's/^bBatchLocal=.*/bBatchLocal=False/' "$INI"
sed -i 's/^Difficulty=.*/Difficulty=0/' /opt/ut99/System64/User.ini

echo "==> Configuring web admin..."
cat >> "$INI" <<EOF

[UWeb.WebServer]
Applications[0]=UTServerAdmin.UTServerAdmin
ApplicationPaths[0]=/ServerAdmin
Applications[1]=UTServerAdmin.UTImageServer
ApplicationPaths[1]=/images
DefaultApplication=0
bEnabled=True
ListenPort=5080
MaxConnections=30

[UTServerAdmin.UTServerAdmin]
AdminUsername=admin
AdminPassword=${WEBADMIN_PASSWORD}

[Engine.GameInfo]
AdminPassword=${INGAME_ADMIN_PASSWORD}
LoginDelaySeconds=1.000000
MaxLoginAttempts=50
EOF
chmod 600 "$INI"

ufw --force reset > /dev/null
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow 22/tcp > /dev/null
ufw allow 7777:7779/udp > /dev/null
ufw allow 80/tcp > /dev/null
ufw allow 443/tcp > /dev/null
ufw --force enable > /dev/null

echo "==> Installing Caddy..."
apt-get -o DPkg::Lock::Timeout=120 install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get -o DPkg::Lock::Timeout=120 update -qq
apt-get -o DPkg::Lock::Timeout=120 install -y -qq caddy

echo "==> Configuring Caddy..."
cat > /etc/caddy/Caddyfile <<EOF
${DOMAIN} {
    redir / /ServerAdmin/ permanent
    reverse_proxy localhost:5080
}
EOF
systemctl enable caddy > /dev/null
systemctl restart caddy

systemctl enable ut99 > /dev/null

echo "==> Provisioning complete"
