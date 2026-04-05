# 🎬 Stash — Proxmox VE LXC Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Stash](https://img.shields.io/badge/Stash-Docs-blue)](https://docs.stashapp.cc)

> Installiert [Stash](https://github.com/stashapp/stash) als Docker-Container in einem Proxmox LXC mit optionaler NAS-Freigabe (CIFS/SMB oder NFS).

-----

## 🚀 Installation

Diesen Befehl im **Proxmox Shell** ausführen:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DEIN_GITHUB_USER/DEIN_REPO/main/ct/stash.sh)"
```

> ⚠️ `DEIN_GITHUB_USER` und `DEIN_REPO` durch deinen GitHub-Benutzernamen und Repository-Namen ersetzen!

Das Script führt dich interaktiv durch die Installation.

-----

## ✨ Was wird installiert?

|Komponente         |Details                                    |
|-------------------|-------------------------------------------|
|**LXC Container**  |Debian 12, privilegiert (für Docker)       |
|**Docker Engine**  |Aktuelle Version via offizielles Repository|
|**Stash**          |`stashapp/stash:latest` via Docker Compose |
|**NAS-Support**    |CIFS/SMB + NFS optional konfigurierbar     |
|**Systemd Service**|Auto-Start, Auto-Update Pull               |

-----

## ⚙️ Konfigurationsmöglichkeiten

### Container

|Option      |Standard     |Beschreibung               |
|------------|-------------|---------------------------|
|Container ID|nächste freie|Proxmox CT-ID              |
|Hostname    |`stash`      |Container-Hostname         |
|CPU         |2 Kerne      |Empfohlen: 2-4             |
|RAM         |2048 MB      |Empfohlen: 2-4 GB          |
|Disk        |16 GB        |Für Config/Cache/Thumbnails|
|Port        |9999         |Stash Web-Interface        |

### NAS Freigabe (optional)

|Option      |Beschreibung                            |
|------------|----------------------------------------|
|Typ         |CIFS/SMB oder NFS                       |
|Server      |IP oder Hostname der NAS                |
|Freigabe    |Share-Name (CIFS) oder Export-Pfad (NFS)|
|Zugangsdaten|Benutzer/Passwort/Domain (nur CIFS)     |
|Mountpoint  |Pfad im Container (Standard: `/mnt/nas`)|

-----

## 📁 Verzeichnisstruktur

```
/opt/stash/
├── docker-compose.yml    # Docker Compose Konfiguration
├── config/              # Stash Konfiguration, Scrapers, Plugins
├── data/                # Medienbibliothek (oder NAS-Mount)
├── metadata/            # Stash Datenbank
├── cache/               # Cache
├── blobs/               # Cover, Bilder (Binary Blobs)
└── generated/           # Vorschaubilder, Transcodes, Sprites
```

-----

## 🌐 Stash Bibliothek einrichten

Nach der Installation:

1. **Stash öffnen:** `http://CONTAINER-IP:9999`
1. **Einstellungen → Bibliothek** aufrufen
1. **Verzeichnis hinzufügen:**
- Ohne NAS: `./data` (lokaler Ordner)
- Mit NAS: `/data` (entspricht dem NAS-Mountpoint)
1. **Speichern** → **Scan starten**

### Regex-Ausschlüsse (Beispiele)

In Stash → Einstellungen → Bibliothek → Ausgeschlossene Muster:

```
sample\.mp4$              # Beispieldateien ausschließen
/\.[[:word:]]+/           # Versteckte Verzeichnisse
\.srt$                    # Untertitel-Dateien
```

-----

## 🔄 Stash aktualisieren

```bash
# Von außen (Proxmox Shell):
pct exec CONTAINER_ID -- update

# Im Container selbst:
update

# Manuell:
cd /opt/stash && docker compose pull && docker compose up -d
```

-----

## 🛠️ Fehlerbehebung

```bash
# Container Shell öffnen
pct enter CONTAINER_ID

# Stash Logs anzeigen
docker logs stash -f

# Stash Status prüfen
cd /opt/stash && docker compose ps

# NAS Mount prüfen
mount | grep nas
df -h /mnt/nas

# NAS manuell remounten
mount -a

# Stash neu starten
cd /opt/stash && docker compose restart
```

### CIFS/SMB Verbindungsprobleme

```bash
# CIFS Verbindung testen
mount -t cifs //NAS-IP/SHARE /mnt/test \
  -o credentials=/etc/stash-nas.credentials,vers=3.0

# Credentials prüfen (root only!)
cat /etc/stash-nas.credentials

# SMB-Version erzwingen
# fstab bearbeiten: vers=3.0 → vers=2.0 oder vers=1.0 (ältere NAS)
nano /etc/fstab
```

### NFS Verbindungsprobleme

```bash
# NFS Exports der NAS anzeigen
showmount -e NAS-IP

# NFS manuell testen
mount -t nfs NAS-IP:/export/pfad /mnt/test
```

-----

## 📂 Repository Struktur

```
.
├── ct/
│   └── stash.sh              # Hauptskript (läuft auf Proxmox Host)
├── install/
│   └── stash-install.sh      # Install-Skript (läuft im LXC Container)
├── json/
│   └── stash.json            # Metadaten (für Webfrontend)
└── README.md
```

-----

## 🔗 Links

- [Stash Dokumentation](https://docs.stashapp.cc)
- [Stash GitHub](https://github.com/stashapp/stash)
- [Stash Docker Hub](https://hub.docker.com/r/stashapp/stash)
- [StashDB](https://stashdb.org) — Community Metadaten-Datenbank
- [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)

-----

## 📜 Lizenz

MIT — basierend auf dem Muster von [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)