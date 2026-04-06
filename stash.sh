#!/usr/bin/env bash

# ============================================================

# Stash LXC Container Installer für Proxmox VE

# Inspiriert von community-scripts/ProxmoxVE

# GitHub:  https://github.com/Nanja-at-web/StashAtProxmox

# Quelle:  https://github.com/stashapp/stash

# Docs:    https://docs.stashapp.cc

# ============================================================

# Verwendung (Proxmox Shell):

# bash -c “$(curl -fsSL https://raw.githubusercontent.com/Nanja-at-web/StashAtProxmox/main/ct/stash.sh)”

# ============================================================

# –– GitHub Repository ––

GITHUB_RAW=“https://raw.githubusercontent.com/Nanja-at-web/StashAtProxmox/main”

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

# –– Hilfsfunktionen ––

msg_info()  { local msg=”$1”; echo -ne “ ${HOLD} ${YW}${msg}…${CL}”; }
msg_ok()    { local msg=”$1”; echo -e “${BFR} ${CM} ${GN}${msg}${CL}”; }
msg_error() { local msg=”$1”; echo -e “${BFR} ${CROSS} ${RD}${msg}${CL}”; }
msg_warn()  { local msg=”$1”; echo -e “ ${YW}⚠  ${msg}${CL}”; }

header_info() {
clear
echo -e “${GN}”
cat <<‘BANNER’

-----

/ ****| |           | |  
| (*** | |* __ _ ***| |**  
_*_ | **/ _` / **| ’* \
__**) | || (*| _* \ | | |
|*****/ _*_*,*|***/*| |*|
BANNER
echo -e “${CL}”
echo -e “  ${GN}Stash Media Organizer — LXC Installer für Proxmox VE${CL}”
echo -e “  ${BL}https://docs.stashapp.cc${CL}”
echo “”
}

# –– Proxmox Prüfung ––

check_proxmox() {
if ! command -v pct &>/dev/null; then
echo -e “${CROSS} ${RD}Dieses Skript muss auf einem Proxmox VE Host ausgeführt werden!${CL}”
exit 1
fi
if [[ “$(id -u)” -ne 0 ]]; then
echo -e “${CROSS} ${RD}Root-Rechte erforderlich!${CL}”
exit 1
fi
}

# –– Nächste freie Container-ID ––

get_nextid() {
pvesh get /cluster/nextid 2>/dev/null || echo “100”
}

# –– Standard-Storage ermitteln ––

get_default_storage() {
pvesm status -content rootdir 2>/dev/null | awk ‘NR>1 {print $1; exit}’
}

# –– Liste aller geeigneten Storages ––

get_storage_list() {
pvesm status -content rootdir 2>/dev/null | awk ‘NR>1 {print $1}’ | paste -sd ‘,’ -
}

# –– Debian 12 Template finden ––

find_template() {
local storage=”$1”

# Zuerst im angegebenen Storage suchen

local tpl
tpl=$(pveam list “$storage” 2>/dev/null | grep -i “debian-12” | tail -1 | awk ‘{print $1}’)
if [[ -n “$tpl” ]]; then
echo “$tpl”
return
fi

# Dann in allen Storages suchen

for s in $(pvesm status -content vztmpl 2>/dev/null | awk ‘NR>1 {print $1}’); do
tpl=$(pveam list “$s” 2>/dev/null | grep -i “debian-12” | tail -1 | awk ‘{print $1}’)
if [[ -n “$tpl” ]]; then
echo “$tpl”
return
fi
done
}

# –– Template herunterladen ––

download_template() {
local storage=”$1”
msg_info “Suche Debian 12 Template im Proxmox Repository”
pveam update >/dev/null 2>&1
local tpl_name
tpl_name=$(pveam available –section system 2>/dev/null   
| grep “debian-12-standard”   
| sort -V | tail -1   
| awk ‘{print $2}’)
if [[ -z “$tpl_name” ]]; then
msg_error “Kein Debian 12 Template verfügbar!”
exit 1
fi
msg_info “Lade Template herunter: ${tpl_name}”
pveam download “$storage” “$tpl_name” >/dev/null 2>&1 || {
msg_error “Template-Download fehlgeschlagen (Storage: $storage)”
exit 1
}
msg_ok “Template heruntergeladen”
echo “${storage}:vztmpl/${tpl_name}”
}

# ============================================================

# HAUPTPROGRAMM

# ============================================================

header_info
check_proxmox

# –– Standardwerte ––

CTID=$(get_nextid)
DEFAULT_STORAGE=$(get_default_storage)
AVAILABLE_STORAGES=$(get_storage_list)
STASH_PORT=“9999”

# ============================================================

# SCHRITT 1: Container Basis-Konfiguration

# ============================================================

whiptail –title “STASH Installer” –msgbox   
“Willkommen zum Stash LXC Installer!\n\nDieses Skript erstellt einen Proxmox LXC Container\nund installiert Stash als Docker-Container.\n\nStash ist ein Media-Organizer fuer deine Film-\nund Bildsammlung.\n\nDeine QNAP TS-210 NAS (192.168.1.xx) kann als\nMedienbibliothek direkt eingebunden werden.\n\nGitHub: github.com/Nanja-at-web/StashAtProxmox\n\nWeiter mit OK…”   
20 65

CTID=$(whiptail –inputbox   
“Container ID\n(Nächste freie ID wird vorgeschlagen)”   
9 60 “$CTID”   
–title “STASH — Container ID” 3>&1 1>&2 2>&3) || exit 1

HOSTNAME=$(whiptail –inputbox   
“Hostname des Containers”   
8 60 “stash”   
–title “STASH — Hostname” 3>&1 1>&2 2>&3) || exit 1

# Ressourcen über Radiolist (einfach / leistungsstark / custom)

RESOURCE_PRESET=$(whiptail –title “STASH — Ressourcen” –radiolist   
“Ressourcen-Preset wählen:\n(Leertaste = Auswählen)”   
14 65 3   
“default”  “Standard:  2 CPU | 2048 MB RAM | 16 GB Disk” ON   
“powerful”  “Leistung:  4 CPU | 4096 MB RAM | 32 GB Disk” OFF   
“custom”   “Benutzerdefiniert…” OFF   
3>&1 1>&2 2>&3) || exit 1

case “$RESOURCE_PRESET” in
“default”)
CPU=2; RAM=2048; DISK=16 ;;
“powerful”)
CPU=4; RAM=4096; DISK=32 ;;
“custom”)
CPU=$(whiptail –inputbox “CPU Kerne” 8 60 “2” –title “STASH — CPU” 3>&1 1>&2 2>&3) || exit 1
RAM=$(whiptail –inputbox “RAM in MB” 8 60 “2048” –title “STASH — RAM” 3>&1 1>&2 2>&3) || exit 1
DISK=$(whiptail –inputbox “Disk Größe in GB” 8 60 “16” –title “STASH — Disk” 3>&1 1>&2 2>&3) || exit 1
;;
esac

STORAGE=$(whiptail –inputbox   
“Proxmox Storage Name\n(Verfügbar: ${AVAILABLE_STORAGES})”   
9 65 “$DEFAULT_STORAGE”   
–title “STASH — Storage” 3>&1 1>&2 2>&3) || exit 1

STASH_PORT=$(whiptail –inputbox   
“Stash Web-Port\n(Standard: 9999)”   
8 60 “9999”   
–title “STASH — Web-Port” 3>&1 1>&2 2>&3) || exit 1

# ============================================================

# SCHRITT 2: NAS Freigabe konfigurieren

# ============================================================

NAS_ENABLED=“no”
NAS_TYPE=“cifs”
NAS_SERVER=””
NAS_SHARE=””
NAS_USER=””
NAS_PASS=””
NAS_DOMAIN=“WORKGROUP”
NAS_MOUNT=”/mnt/qnap”
NAS_OPTIONS=””

if whiptail –title “STASH — QNAP NAS Freigabe” –yesno   
“QNAP TS-210 NAS Freigabe einbinden?\n\nStash greift direkt auf deine QNAP-Medienbibliothek zu.\n\nUnterstützte Protokolle:\n  • SMB/CIFS  (empfohlen für QNAP TS-210)\n  • NFS        (alternativ, muss am QNAP aktiviert sein)\n\nBenötigt: QNAP IP-Adresse (z.B. 192.168.1.xx)\n           und einen QNAP-Benutzer mit Zugriff.\n\nJetzt konfigurieren?”   
18 68; then

NAS_ENABLED=“yes”

NAS_TYPE=$(whiptail –title “STASH — NAS Protokoll” –radiolist   
“NAS Protokoll wählen:\n(QNAP TS-210 empfiehlt SMB/CIFS)\n(Leertaste = Auswählen)”   
13 68 2   
“cifs” “SMB/CIFS  (empfohlen — QNAP Netzwerkfreigabe)” ON   
“nfs”  “NFS        (alternativ — muss in QNAP aktiviert sein)” OFF   
3>&1 1>&2 2>&3) || exit 1

NAS_SERVER=$(whiptail –inputbox   
“QNAP TS-210 IP-Adresse\nBeispiel: 192.168.1.50  oder  192.168.1.100”   
9 68 “192.168.1.”   
–title “STASH — QNAP IP-Adresse” 3>&1 1>&2 2>&3) || exit 1

if [[ “$NAS_TYPE” == “cifs” ]]; then
NAS_SHARE=$(whiptail –inputbox   
“QNAP Freigabename (ohne Schrägstriche)\nTypische QNAP-Freigaben: Multimedia, Public, Download\nEigene Freigaben findest du in der QNAP Verwaltung.”   
11 68 “Multimedia”   
–title “STASH — QNAP Freigabename” 3>&1 1>&2 2>&3) || exit 1

```
NAS_USER=$(whiptail --inputbox \
  "QNAP Benutzername\n(QNAP-Benutzer mit Zugriff auf die Freigabe)" \
  9 68 "admin" \
  --title "STASH — QNAP Benutzer" 3>&1 1>&2 2>&3) || exit 1

NAS_PASS=$(whiptail --passwordbox \
  "QNAP Passwort für Benutzer '${NAS_USER}'" \
  8 68 "" \
  --title "STASH — QNAP Passwort" 3>&1 1>&2 2>&3) || exit 1

NAS_DOMAIN=$(whiptail --inputbox \
  "CIFS Domain / Arbeitsgruppe\n(QNAP Standard: WORKGROUP — i.d.R. nicht anpassen noetig)" \
  9 68 "WORKGROUP" \
  --title "STASH — QNAP Domain" 3>&1 1>&2 2>&3) || exit 1

# QNAP TS-210: aelteres Geraet, vers=2.0 sicherer als vers=3.0
NAS_OPTIONS=$(whiptail --inputbox \
  "CIFS Mount-Optionen (optional — leer lassen fuer QNAP-Optimum)\n\nStandard fuer QNAP TS-210: vers=2.0 (SMB2)\nFalls Probleme: vers=1.0 eintragen (aeltere QTS-Versionen)" \
  12 70 "" \
  --title "STASH — QNAP CIFS Optionen" 3>&1 1>&2 2>&3) || exit 1
```

else
NAS_SHARE=$(whiptail –inputbox   
“NFS Export-Pfad auf der QNAP\nIn QNAP Verwaltung unter: Netzwerk-Dienste → NFS\nBeispiel: /Multimedia  oder  /share/Multimedia”   
11 68 “/Multimedia”   
–title “STASH — QNAP NFS Export” 3>&1 1>&2 2>&3) || exit 1

```
# QNAP TS-210 unterstützt zuverlässig NFSv3
NAS_OPTIONS=$(whiptail --inputbox \
  "NFS Mount-Optionen (optional — leer lassen fuer QNAP-Optimum)\n\nStandard fuer QNAP TS-210: nfsvers=3,_netdev\n(TS-210 unterstuetzt NFSv3 stabiler als NFSv4)" \
  12 70 "" \
  --title "STASH — QNAP NFS Optionen" 3>&1 1>&2 2>&3) || exit 1
```

fi

NAS_MOUNT=$(whiptail –inputbox   
“Mountpoint im Container\n(Hier wird die QNAP-Freigabe eingehängt)”   
9 65 “/mnt/qnap”   
–title “STASH — Mountpoint” 3>&1 1>&2 2>&3) || exit 1
fi

# ============================================================

# SCHRITT 3: Zusammenfassung & Bestätigung

# ============================================================

NAS_SUMMARY=“Nein”
if [[ “$NAS_ENABLED” == “yes” ]]; then
if [[ “$NAS_TYPE” == “cifs” ]]; then
NAS_SUMMARY=“CIFS: //${NAS_SERVER}/${NAS_SHARE} → ${NAS_MOUNT}”
else
NAS_SUMMARY=“NFS: ${NAS_SERVER}:${NAS_SHARE} → ${NAS_MOUNT}”
fi
fi

whiptail –title “STASH — Installationsübersicht” –yesno   
“Folgende Konfiguration wird installiert:

Container ID:    ${CTID}
Hostname:        ${HOSTNAME}
CPU Kerne:       ${CPU}
RAM:             ${RAM} MB
Disk:            ${DISK} GB
Storage:         ${STORAGE}
Stash Port:      ${STASH_PORT}

NAS Freigabe:    ${NAS_SUMMARY}

Jetzt installieren?”   
20 65 || { echo “Installation abgebrochen.”; exit 0; }

# ============================================================

# SCHRITT 4: Template suchen / laden

# ============================================================

header_info
echo -e “  ${GN}Starte Installation…${CL}”
echo “”

msg_info “Suche Debian 12 Template”
TEMPLATE=$(find_template “$STORAGE”)
if [[ -z “$TEMPLATE” ]]; then
msg_warn “Kein lokales Template gefunden — wird heruntergeladen”
TEMPLATE=$(download_template “$STORAGE”)
else
msg_ok “Template gefunden: $(basename “$TEMPLATE”)”
fi

# ============================================================

# SCHRITT 5: LXC Container erstellen

# ============================================================

msg_info “Erstelle LXC Container ${CTID} (${HOSTNAME})”
pct create “${CTID}” “${TEMPLATE}”   
–hostname “${HOSTNAME}”   
–cores “${CPU}”   
–memory “${RAM}”   
–rootfs “${STORAGE}:${DISK}”   
–net0 “name=eth0,bridge=vmbr0,ip=dhcp,ip6=auto,firewall=1”   
–features “nesting=1,keyctl=1,fuse=1”   
–unprivileged 0   
–onboot 1   
–start 0   
–tags “stash;docker;media”   
2>/dev/null

if [[ $? -ne 0 ]]; then
msg_error “Container-Erstellung fehlgeschlagen! (ID: ${CTID}, Storage: ${STORAGE})”
exit 1
fi
msg_ok “Container ${CTID} erstellt”

# –– Zusätzliche LXC-Konfiguration für Docker ––

msg_info “Konfiguriere Container für Docker”
{
echo “lxc.apparmor.profile: unconfined”
echo “lxc.cgroup.devices.allow: a”
echo “lxc.cap.drop:”
} >> /etc/pve/lxc/${CTID}.conf
msg_ok “Docker-Konfiguration gesetzt”

# ============================================================

# SCHRITT 6: Container starten

# ============================================================

msg_info “Starte Container ${CTID}”
pct start “${CTID}”

# Warte bis Container vollständig hochgefahren

echo -ne “ ${HOLD} ${YW}Warte auf Container-Start…${CL}”
for i in {1..30}; do
sleep 2
if pct exec “${CTID}” – bash -c “hostname” &>/dev/null; then
break
fi
echo -ne “.”
done
msg_ok “Container ${CTID} läuft”

# ============================================================

# SCHRITT 7: Install-Script im Container ausführen

# ============================================================

msg_info “Führe Stash Installation im Container aus”

# NAS-Konfiguration als Umgebungsvariablen übergeben

pct exec “${CTID}” – bash -c “
export NAS_ENABLED=’${NAS_ENABLED}’
export NAS_TYPE=’${NAS_TYPE}’
export NAS_SERVER=’${NAS_SERVER}’
export NAS_SHARE=’${NAS_SHARE}’
export NAS_USER=’${NAS_USER}’
export NAS_PASS=’${NAS_PASS}’
export NAS_DOMAIN=’${NAS_DOMAIN}’
export NAS_MOUNT=’${NAS_MOUNT}’
export NAS_OPTIONS=’${NAS_OPTIONS}’
export STASH_PORT=’${STASH_PORT}’
bash <(curl -fsSL ‘${GITHUB_RAW}/install/stash-install.sh’)
“ 2>&1

if [[ $? -ne 0 ]]; then
msg_error “Installation fehlgeschlagen!”
echo “”
echo -e “  ${INFO} Fehlerbehebung:”
echo -e “  ${TAB}pct enter ${CTID}  # Container-Shell öffnen”
echo -e “  ${TAB}journalctl -xe     # System-Logs prüfen”
exit 1
fi

msg_ok “Stash Installation abgeschlossen”

# ============================================================

# SCHRITT 8: Abschluss & Ausgabe

# ============================================================

IP=$(pct exec “${CTID}” – hostname -I 2>/dev/null | awk ‘{print $1}’)

echo “”
echo -e “${GN}╔══════════════════════════════════════════════╗${CL}”
echo -e “${GN}║      Stash wurde erfolgreich installiert!    ║${CL}”
echo -e “${GN}╚══════════════════════════════════════════════╝${CL}”
echo “”
echo -e “  ${YW}🌐  Web-Interface:${CL}  ${GN}http://${IP}:${STASH_PORT}${CL}”
echo “”
if [[ “$NAS_ENABLED” == “yes” ]]; then
echo -e “  ${YW}💾  NAS Freigabe:${CL}   ${NAS_MOUNT}”
echo -e “  ${INFO}  In Stash unter Einstellungen → Bibliothek → Verzeichnis hinzufügen:”
echo -e “  ${TAB}${GN}/data${CL}  (entspricht ${NAS_MOUNT} auf dem Host)”
echo “”
fi
echo -e “  ${BL}Container verwalten:${CL}”
echo -e “  ${TAB}pct enter ${CTID}                      ${YW}# Shell öffnen${CL}”
echo -e “  ${TAB}pct exec ${CTID} – update              ${YW}# Stash aktualisieren${CL}”
echo -e “  ${TAB}pct exec ${CTID} – docker logs stash   ${YW}# Stash Logs${CL}”
echo -e “  ${TAB}pct stop ${CTID}                        ${YW}# Container stoppen${CL}”
echo “”
echo -e “  ${BL}Stash Konfiguration liegt in:${CL}  /opt/stash/”
echo “”