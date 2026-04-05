#!/usr/bin/env bash

# ============================================================

# Stash Install Script — läuft INNERHALB des LXC Containers

# Installiert Docker + Stash und konfiguriert NAS-Freigabe

# Quelle: https://github.com/stashapp/stash

# ============================================================

set -euo pipefail

# –– Farben & Symbole ––

YW=”\033[33m”
BL=”\033[36m”
RD=”\033[01;31m”
GN=”\033[1;92m”
CL=”\033[m”
BFR=”\r\033[K”
HOLD=” “
CM=”${GN}✓${CL}”
CROSS=”${RD}✗${CL}”
INFO=”${BL}ℹ${CL}”
TAB=”    “

msg_info()  { local msg=”$1”; echo -ne “ ${HOLD} ${YW}${msg}…${CL}”; }
msg_ok()    { local msg=”$1”; echo -e “${BFR} ${CM} ${GN}${msg}${CL}”; }
msg_error() { local msg=”$1”; echo -e “${BFR} ${CROSS} ${RD}${msg}${CL}”; exit 1; }
msg_warn()  { local msg=”$1”; echo -e “ ${YW}⚠  ${msg}${CL}”; }

# –– Konfiguration aus Umgebungsvariablen ––

NAS_ENABLED=”${NAS_ENABLED:-no}”
NAS_TYPE=”${NAS_TYPE:-cifs}”
NAS_SERVER=”${NAS_SERVER:-}”
NAS_SHARE=”${NAS_SHARE:-}”
NAS_USER=”${NAS_USER:-}”
NAS_PASS=”${NAS_PASS:-}”
NAS_DOMAIN=”${NAS_DOMAIN:-WORKGROUP}”
NAS_MOUNT=”${NAS_MOUNT:-/mnt/nas}”
NAS_OPTIONS=”${NAS_OPTIONS:-}”
STASH_PORT=”${STASH_PORT:-9999}”

# ============================================================

# SYSTEM VORBEREITUNG

# ============================================================

msg_info “System wird aktualisiert”
apt-get update -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq >/dev/null
msg_ok “System aktualisiert”

msg_info “Basis-Pakete werden installiert”
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq   
curl   
wget   
ca-certificates   
gnupg   
lsb-release   
apt-transport-https   
software-properties-common   
htop   
nano   
net-tools \

> /dev/null
> msg_ok “Basis-Pakete installiert”

# ============================================================

# NAS PAKETE

# ============================================================

if [[ “${NAS_ENABLED}” == “yes” ]]; then
if [[ “${NAS_TYPE}” == “cifs” ]]; then
msg_info “CIFS-Pakete werden installiert”
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq   
cifs-utils   
keyutils   
>/dev/null
msg_ok “CIFS-Pakete installiert”
else
msg_info “NFS-Pakete werden installiert”
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq   
nfs-common   
>/dev/null
msg_ok “NFS-Pakete installiert”
fi
fi

# ============================================================

# DOCKER INSTALLATION

# ============================================================

msg_info “Docker GPG-Schlüssel wird hinzugefügt”
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg   
| gpg –dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
chmod a+r /etc/apt/keyrings/docker.gpg
msg_ok “Docker GPG-Schlüssel hinzugefügt”

msg_info “Docker Repository wird eingerichtet”
echo   
“deb [arch=$(dpkg –print-architecture) signed-by=/etc/apt/keyrings/docker.gpg]   
https://download.docker.com/linux/debian   
$(. /etc/os-release && echo “${VERSION_CODENAME}”) stable” \

> /etc/apt/sources.list.d/docker.list
> apt-get update -qq >/dev/null
> msg_ok “Docker Repository eingerichtet”

msg_info “Docker Engine wird installiert”
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq   
docker-ce   
docker-ce-cli   
containerd.io   
docker-buildx-plugin   
docker-compose-plugin \

> /dev/null
> msg_ok “Docker Engine installiert”

msg_info “Docker Daemon wird gestartet”
systemctl enable docker –now >/dev/null 2>&1

# Kurz warten bis Docker bereit ist

sleep 3
docker info >/dev/null 2>&1 || msg_error “Docker-Daemon konnte nicht gestartet werden!”
msg_ok “Docker Daemon läuft”

# Docker Version ausgeben

DOCKER_VERSION=$(docker –version | awk ‘{print $3}’ | tr -d ‘,’)
echo -e “  ${INFO} Docker Version: ${GN}${DOCKER_VERSION}${CL}”

# ============================================================

# VERZEICHNISSTRUKTUR

# ============================================================

msg_info “Stash Verzeichnisstruktur wird angelegt”
mkdir -p /opt/stash/{config,data,metadata,cache,blobs,generated}
chmod -R 755 /opt/stash
msg_ok “Verzeichnisse erstellt: /opt/stash/”

# ============================================================

# NAS FREIGABE EINBINDEN

# ============================================================

if [[ “${NAS_ENABLED}” == “yes” ]]; then
msg_info “NAS Mountpoint wird erstellt: ${NAS_MOUNT}”
mkdir -p “${NAS_MOUNT}”
msg_ok “Mountpoint erstellt”

if [[ “${NAS_TYPE}” == “cifs” ]]; then
# –– CIFS / SMB Konfiguration ––
msg_info “CIFS Credentials werden gespeichert”
cat > /etc/stash-nas.credentials << EOF
username=${NAS_USER}
password=${NAS_PASS}
domain=${NAS_DOMAIN}
EOF
chmod 600 /etc/stash-nas.credentials
msg_ok “Credentials gespeichert: /etc/stash-nas.credentials”

```
# CIFS Mount-Optionen zusammenbauen
CIFS_BASE_OPTS="credentials=/etc/stash-nas.credentials,iocharset=utf8,vers=3.0,uid=0,gid=0,file_mode=0777,dir_mode=0777,_netdev"
if [[ -n "${NAS_OPTIONS}" ]]; then
  CIFS_MOUNT_OPTS="${CIFS_BASE_OPTS},${NAS_OPTIONS}"
else
  CIFS_MOUNT_OPTS="${CIFS_BASE_OPTS}"
fi

FSTAB_ENTRY="//${NAS_SERVER}/${NAS_SHARE} ${NAS_MOUNT} cifs ${CIFS_MOUNT_OPTS} 0 0"

msg_info "CIFS Mount wird eingerichtet (//${NAS_SERVER}/${NAS_SHARE})"
```

else
# –– NFS Konfiguration ––
NFS_BASE_OPTS=“nfsvers=4,_netdev,timeo=14,retry=3”
if [[ -n “${NAS_OPTIONS}” ]]; then
NFS_MOUNT_OPTS=”${NFS_BASE_OPTS},${NAS_OPTIONS}”
else
NFS_MOUNT_OPTS=”${NFS_BASE_OPTS}”
fi

```
FSTAB_ENTRY="${NAS_SERVER}:${NAS_SHARE} ${NAS_MOUNT} nfs ${NFS_MOUNT_OPTS} 0 0"

msg_info "NFS Mount wird eingerichtet (${NAS_SERVER}:${NAS_SHARE})"
```

fi

# fstab sichern und Eintrag hinzufügen

cp /etc/fstab /etc/fstab.stash.bak
echo “” >> /etc/fstab
echo “# Stash NAS Freigabe (hinzugefügt vom Stash Installer)” >> /etc/fstab
echo “${FSTAB_ENTRY}” >> /etc/fstab

# Ersten Mount-Versuch starten

if mount “${NAS_MOUNT}” 2>/dev/null; then
msg_ok “NAS erfolgreich eingehängt: ${NAS_MOUNT}”
NAS_DATA_PATH=”${NAS_MOUNT}”
else
msg_warn “NAS konnte beim ersten Versuch nicht eingehängt werden.”
msg_warn “fstab-Eintrag wurde trotzdem gespeichert.”
msg_warn “Nach dem Reboot wird die Freigabe automatisch eingehängt.”
msg_warn “Manuell prüfen: mount ${NAS_MOUNT}”
NAS_DATA_PATH=”${NAS_MOUNT}”
fi

DATA_VOLUME=”${NAS_MOUNT}:/data”
else
DATA_VOLUME=”./data:/data”
fi

# ============================================================

# DOCKER COMPOSE KONFIGURATION

# ============================================================

msg_info “Docker Compose Datei wird erstellt”

cat > /opt/stash/docker-compose.yml << DOCKERCOMPOSE

# ============================================================

# Stash Media Organizer — Docker Compose Konfiguration

# Web-Interface: http://HOST-IP:${STASH_PORT}

# Docs: https://docs.stashapp.cc

# ============================================================

services:
stash:
image: stashapp/stash:latest
container_name: stash
restart: unless-stopped

```
# Web-Interface Port
ports:
  - "${STASH_PORT}:${STASH_PORT}"

# Logging Konfiguration
logging:
  driver: "json-file"
  options:
    max-file: "10"
    max-size: "2m"

# Stash Umgebungsvariablen
environment:
  # Medienbibliothek-Pfad (innerhalb des Containers)
  - STASH_STASH=/data/
  # Generierte Dateien (Vorschaubilder, Transcodes, Sprites)
  - STASH_GENERATED=/generated/
  # Metadaten-Datenbank
  - STASH_METADATA=/metadata/
  # Cache-Verzeichnis
  - STASH_CACHE=/cache/
  # Web-Port
  - STASH_PORT=${STASH_PORT}

volumes:
  # Zeitzone synchronisieren
  - /etc/localtime:/etc/localtime:ro

  # ---- Stash Konfiguration (Scrapers, Plugins) ----
  - ./config:/root/.stash

  # ---- Medienbibliothek ----
  # Links: Pfad auf dem Host / Rechts: Pfad im Stash-Container
  # In Stash unter Einstellungen → Bibliothek → /data hinzufügen
  - ${DATA_VOLUME}

  # ---- Stash interne Verzeichnisse ----
  - ./metadata:/metadata
  - ./cache:/cache
  - ./blobs:/blobs
  - ./generated:/generated

# Gesundheitsprüfung
healthcheck:
  test: ["CMD", "wget", "-qO-", "http://localhost:${STASH_PORT}/healthz"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

DOCKERCOMPOSE

msg_ok “Docker Compose erstellt: /opt/stash/docker-compose.yml”

# ============================================================

# SYSTEMD SERVICE

# ============================================================

msg_info “Systemd Service wird erstellt”

# NAS-Abhängigkeit für systemd

if [[ “${NAS_ENABLED}” == “yes” ]]; then

# Mountpoint-Einheit aus Pfad ableiten (z.B. /mnt/nas → mnt-nas.mount)

NAS_SYSTEMD_UNIT=$(systemd-escape –path “${NAS_MOUNT}”).mount
AFTER_NAS=“After=${NAS_SYSTEMD_UNIT}
Wants=${NAS_SYSTEMD_UNIT}”
else
AFTER_NAS=””
fi

cat > /etc/systemd/system/stash.service << SYSTEMD
[Unit]
Description=Stash Media Organizer (Docker Compose)
Documentation=https://docs.stashapp.cc
After=docker.service network-online.target
Requires=docker.service
${AFTER_NAS}

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/stash
ExecStartPre=/usr/bin/docker compose pull –quiet
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload >/dev/null 2>&1
systemctl enable stash.service >/dev/null 2>&1
msg_ok “Systemd Service aktiviert (stash.service)”

# ============================================================

# UPDATE SCRIPT

# ============================================================

msg_info “Update-Script wird erstellt”
cat > /usr/bin/update << ‘UPDATESCRIPT’
#!/usr/bin/env bash

# Stash Update Script

# Verwendung: update

YW=”\033[33m”; GN=”\033[1;92m”; CL=”\033[m”
CM=”${GN}✓${CL}”

echo “”
echo -e “  ${YW}Stash wird auf die neueste Version aktualisiert…${CL}”
echo “”

cd /opt/stash

echo -ne “  Neues Image wird heruntergeladen…”
docker compose pull –quiet 2>/dev/null
echo -e “\r  ${CM} Image heruntergeladen”

echo -ne “  Container wird neu gestartet…”
docker compose up -d 2>/dev/null
echo -e “\r  ${CM} Container neu gestartet”

echo “”
echo -e “  ${GN}Stash Update abgeschlossen!${CL}”
echo -e “  Version: $(docker inspect stash –format ‘{{.Config.Image}}’ 2>/dev/null)”
echo “”
UPDATESCRIPT
chmod +x /usr/bin/update
msg_ok “Update-Script erstellt: /usr/bin/update”

# ============================================================

# STASH STARTEN

# ============================================================

msg_info “Stash Docker Image wird heruntergeladen”
cd /opt/stash
docker compose pull 2>&1 | grep -E “Pulling|Pulled|up to date” | sed ‘s/^/  /’
msg_ok “Image heruntergeladen”

msg_info “Stash wird gestartet”
docker compose up -d >/dev/null 2>&1
sleep 5

# Prüfen ob Container läuft

if docker ps –filter “name=stash” –filter “status=running” | grep -q “stash”; then
msg_ok “Stash Container läuft”
else
msg_warn “Stash Container Status unbekannt — bitte manuell prüfen”
msg_warn “cd /opt/stash && docker compose logs”
fi

# ============================================================

# MOTD / Login-Nachricht

# ============================================================

IP=$(hostname -I | awk ‘{print $1}’)

cat > /etc/motd << MOTD

╔══════════════════════════════════════════════════════╗
║               Stash Media Organizer                  ║
╠══════════════════════════════════════════════════════╣
║  Web-Interface:  http://${IP}:${STASH_PORT}
║  Konfiguration:  /opt/stash/
MOTD

if [[ “${NAS_ENABLED}” == “yes” ]]; then
cat >> /etc/motd << MOTD
║  NAS Freigabe:   ${NAS_MOUNT}
MOTD
fi

cat >> /etc/motd << MOTD
╠══════════════════════════════════════════════════════╣
║  Befehle:                                            ║
║    update              → Stash aktualisieren         ║
║    cd /opt/stash       → Compose-Verzeichnis         ║
║    docker logs stash   → Stash Logs ansehen          ║
╚══════════════════════════════════════════════════════╝

MOTD

# ============================================================

# ABSCHLUSS

# ============================================================

echo “”
echo -e “  ${GN}╔══════════════════════════════════════════════╗${CL}”
echo -e “  ${GN}║      Stash Installation abgeschlossen!       ║${CL}”
echo -e “  ${GN}╚══════════════════════════════════════════════╝${CL}”
echo “”
echo -e “  🌐  ${YW}Web-Interface:${CL}  ${GN}http://${IP}:${STASH_PORT}${CL}”
echo “”

if [[ “${NAS_ENABLED}” == “yes” ]]; then
echo -e “  💾  ${YW}NAS eingebunden:${CL}  ${NAS_MOUNT}”
echo “”
echo -e “  ${BL}Stash Bibliothek konfigurieren:${CL}”
echo -e “  ${TAB}1. http://${IP}:${STASH_PORT} aufrufen”
echo -e “  ${TAB}2. Einstellungen → Bibliothek”
echo -e “  ${TAB}3. Verzeichnis hinzufügen: ${GN}/data${CL}”
echo -e “  ${TAB}   (entspricht ${NAS_MOUNT} auf dem Host)”
echo -e “  ${TAB}4. Speichern → Scan starten”
echo “”
fi

echo -e “  ${BL}Nützliche Befehle:${CL}”
echo -e “  ${TAB}update                     ${YW}# Stash aktualisieren${CL}”
echo -e “  ${TAB}docker logs stash -f       ${YW}# Live-Logs anzeigen${CL}”
echo -e “  ${TAB}docker compose -f /opt/stash/docker-compose.yml ps  ${YW}# Status${CL}”
echo “”