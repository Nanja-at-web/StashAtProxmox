# 🎬 Stash — Proxmox VE LXC Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-Nanja--at--web%2FStashAtProxmox-blue)](https://github.com/Nanja-at-web/StashAtProxmox)
[![Stash Docs](https://img.shields.io/badge/Stash-Docs-orange)](https://docs.stashapp.cc)

> Installiert [Stash](https://github.com/stashapp/stash) als Docker-Container in einem Proxmox LXC Container —  
> mit direkter Einbindung der **QNAP TS-210 NAS** als Medienbibliothek (CIFS/SMB oder NFS).

-----

## 🚀 Installation (Proxmox Shell)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Nanja-at-web/StashAtProxmox/main/ct/stash.sh)"
```

Das Script führt dich mit interaktiven Menüs durch die komplette Einrichtung — inklusive QNAP-Verbindung.

-----

## ✨ Was wird installiert?

|Komponente         |Details                                                |
|-------------------|-------------------------------------------------------|
|**LXC Container**  |Debian 12, privilegiert (erforderlich für Docker)      |
|**Docker Engine**  |Aktuelle Version via offizielles Docker-Repository     |
|**Stash**          |`stashapp/stash:latest` via Docker Compose             |
|**QNAP NAS**       |CIFS/SMB (empfohlen) oder NFS, automatisch konfiguriert|
|**Systemd Service**|Auto-Start beim Booten, NAS-Mount-Abhängigkeit         |
|**Update-Script**  |`/usr/bin/update` für einfache Stash-Updates           |

-----

## ⚙️ Konfiguration

### LXC Container

|Option      |Standard     |Beschreibung                 |
|------------|-------------|-----------------------------|
|Container ID|nächste freie|Proxmox CT-ID                |
|Hostname    |`stash`      |Container-Hostname           |
|CPU         |2 Kerne      |Empfohlen: 2–4               |
|RAM         |2048 MB      |Empfohlen: 2–4 GB            |
|Disk        |16 GB        |Für Config, Cache, Thumbnails|
|Web-Port    |9999         |`http://CONTAINER-IP:9999`   |

### QNAP TS-210 NAS Einbindung

|Option     |QNAP-Standard |Beschreibung            |
|-----------|--------------|------------------------|
|Protokoll  |CIFS/SMB      |empfohlen für TS-210    |
|IP-Adresse |`192.168.1.xx`|deine QNAP IP           |
|Freigabe   |`Multimedia`  |QNAP Freigabename       |
|Benutzer   |`admin`       |QNAP-Benutzer           |
|Domain     |`WORKGROUP`   |QNAP-Standard           |
|SMB-Version|`vers=2.0`    |TS-210 kompatibel (SMB2)|
|Mountpoint |`/mnt/qnap`   |Pfad im Container       |


> **Hinweis:** Die QNAP-Freigabe erscheint im Stash-Container als `/data`. Diesen Pfad in **Stash → Einstellungen → Bibliothek** eintragen.

-----

## 🖧 QNAP TS-210 vorbereiten

### SMB/CIFS (empfohlen)

1. QNAP Verwaltung: `http://192.168.1.xx`
1. **Systemsteuerung → Dateidienste → SMB** → SMB aktiviert lassen
1. Freigabe-Benutzer prüfen: **Dateistation → Rechtsklick → Berechtigungen**

### NFS (alternativ)

1. **Systemsteuerung → Dateidienste → NFS** → NFS aktivieren
1. **Dateistation → Rechtsklick → Bearbeiten → NFS-Host-Zugriff** → Proxmox-IP eintragen

-----

## 📁 Verzeichnisstruktur im Container

```
/opt/stash/
├── docker-compose.yml    # Docker Compose Konfiguration
├── config/               # Stash Konfiguration, Scrapers, Plugins
├── data/                 # Lokale Mediablage (ohne NAS)
├── metadata/             # Stash SQLite Datenbank
├── cache/                # Stash Cache
├── blobs/                # Coverbilder
└── generated/            # Vorschaubilder, Transcodes, Sprites

/mnt/qnap/                # QNAP TS-210 Freigabe (eingehängt)
/etc/stash-nas.credentials # QNAP Zugangsdaten (chmod 600)
```

-----

## 🌐 Stash Bibliothek einrichten

1. **Stash öffnen:** `http://CONTAINER-IP:9999`
1. **Einstellungen → Bibliothek → Verzeichnis hinzufügen:** `/data`
1. **Speichern → Scan starten**

### Empfohlene Regex-Ausschlüsse (Einstellungen → Bibliothek)

```
sample\.mp4$        # Beispieldateien
/\.[[:word:]]+/     # Versteckte Verzeichnisse
@eaDir/.*           # QNAP-interne Systemordner (wichtig!)
\.DS_Store$         # macOS Systemdateien
```

> ⚠️ **QNAP-spezifisch:** `@eaDir` wird von QNAP automatisch in jeden Ordner erstellt. Das Regex `@eaDir/.*` verhindert, dass Stash diese Systemdaten scannt.

-----

## 🔄 Stash aktualisieren

```bash
# Von Proxmox Shell:
pct exec CONTAINER_ID -- update

# Im Container:
update
```

-----

## 🛠️ Fehlerbehebung

```bash
pct enter CONTAINER_ID          # Container Shell
docker logs stash -f            # Stash Logs
mount | grep qnap               # NAS Mount prüfen
df -h /mnt/qnap                 # NAS verfügbarer Speicher

# QNAP CIFS Verbindung testen:
mount -t cifs //192.168.1.xx/Multimedia /mnt/test \
  -o credentials=/etc/stash-nas.credentials,vers=2.0

# Falls Fehler → ältere QTS Version, SMB1 versuchen:
# /etc/fstab: vers=2.0 → vers=1.0 ändern

# QNAP NFS testen (NFSv3):
showmount -e 192.168.1.xx
mount -t nfs -o nfsvers=3 192.168.1.xx:/Multimedia /mnt/test
```

-----

## 📂 Repository Struktur

```
StashAtProxmox/
├── ct/
│   └── stash.sh              # Hauptskript (läuft auf Proxmox Host)
├── install/
│   └── stash-install.sh      # Install-Skript (läuft im LXC Container)
├── json/
│   └── stash.json            # Metadaten
└── README.md
```

-----

## 🔗 Links

|Resource             |URL                                                                                     |
|---------------------|----------------------------------------------------------------------------------------|
|**Dieses Repository**|[github.com/Nanja-at-web/StashAtProxmox](https://github.com/Nanja-at-web/StashAtProxmox)|
|Stash Dokumentation  |[docs.stashapp.cc](https://docs.stashapp.cc)                                            |
|Stash GitHub         |[github.com/stashapp/stash](https://github.com/stashapp/stash)                          |
|Stash Docker Hub     |[hub.docker.com/r/stashapp/stash](https://hub.docker.com/r/stashapp/stash)              |
|StashDB (Metadaten)  |[stashdb.org](https://stashdb.org)                                                      |
|community-scripts    |[github.com/community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)|

-----

## 📜 Lizenz

MIT — inspiriert von [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE)