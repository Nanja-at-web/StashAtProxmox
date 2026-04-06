# StashApp auf Proxmox LXC (Community-Scripts-Stil)

Dieses Repository enthält ein Community-Scripts-artiges Setup für **StashApp** auf **Proxmox VE** in einem **LXC-Container**.

## Inhalt des Repositories

- `ct/stashapp.sh` — Host-seitiges Proxmox-CT-Skript zum Erstellen bzw. Aktualisieren des Containers
- `install/stashapp-install.sh` — Installationsskript **im** Container für Docker und Stash

## One-Click-Start

Wenn das Repository öffentlich erreichbar ist, kann das CT-Skript direkt aus der Proxmox-Shell gestartet werden:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Nanja-at-web/StashAtProxmox/main/ct/stashapp.sh)"
```

## Was das Skript macht

Das Setup folgt dem allgemeinen Aufbau der Proxmox Community Scripts: ein **CT-Skript** erstellt den LXC und ein **Installationsskript** richtet die Anwendung im Gast ein.

### 1. Es erstellt einen unprivilegierten Debian-LXC

Im Community-Scripts-Projekt werden Container-Skripte im Bereich `ct/` dokumentiert, während containerinterne Installationsskripte im Bereich `install/` liegen. Das offizielle Docker-CT-Skript der Community Scripts setzt standardmäßig:

- `var_os="debian"`
- `var_version="13"`
- `var_unprivileged="1"`

Das StashApp-Skript orientiert sich an diesem Muster.

**Warum unprivilegiert?**  
Ein unprivilegierter LXC ist in Proxmox in der Regel die sicherere Standardwahl. Für Stash ist das sinnvoll, weil die Medien auf einer NAS-Freigabe liegen und die eigentliche Anwendung zusätzlich isoliert per Docker läuft.

### 2. Es installiert Docker im Container

Das Installationsskript richtet Docker im Container ein. Auch das folgt der Logik des offiziellen Docker-Installationsskripts der Community Scripts, das Docker inklusive Compose/Buildx installiert.

Warum Docker?  
Stash dokumentiert Docker Compose als offiziellen Installationsweg. Dabei wird eine `docker-compose.yml` gespeichert, angepasst und anschließend mit `docker compose up -d` gestartet.

### 3. Es erstellt eine Docker-Compose-Konfiguration für Stash

Stash stellt eine offizielle Compose-Vorlage bereit. Dort werden unter anderem diese Pfade verwendet:

- `/data`
- `/generated`
- `/metadata`
- `/cache`
- `/blobs`

Dieses Repository erzeugt eine dazu passende Compose-Datei unter:

```text
/opt/stash/docker-compose.yml
```

Zusätzlich werden lokale Verzeichnisse für Konfiguration und Begleitdaten angelegt:

```text
/opt/stash/config
/opt/stash/metadata
/opt/stash/cache
/opt/stash/blobs
/opt/stash/generated
```

### 4. Es veröffentlicht Stash auf Port 9999

In der offiziellen Docker-Dokumentation von Stash wird der Standard-Port in der Compose-Datei mit

```yaml
ports:
  - "9999:9999"
```

gezeigt. Beim Compose-Start ist Stash danach standardmäßig über Port **9999** erreichbar.

Beispiel:

```text
http://192.168.1.50:9999
```

### 5. Es verwendet standardmäßig `/mnt/stash-library` als Bibliothekspfad im LXC

Das Installationsskript fragt einen Bibliothekspfad im Container ab. Standardmäßig wird verwendet:

```text
/mnt/stash-library
```

Dieser Pfad ist bewusst so gewählt, dass er gut zu einem **Bind-Mount aus Proxmox** passt. Statt die NAS direkt im Docker-Container zu mounten, wird die Freigabe zuerst auf dem **Proxmox-Host** eingebunden und danach in den LXC durchgereicht.

### 6. Es bindet diesen Pfad im Stash-Container als `/data` ein

Die Compose-Datei mappt den Bibliothekspfad des LXC nach `/data` in den eigentlichen Stash-Container.

Beispiel:

- **Proxmox-Host:** `/mnt/qnap-stash`
- **LXC-Container:** `/mnt/stash-library`
- **Stash-Docker-Container:** `/data`

Damit ergibt sich folgende Kette:

```text
QNAP/NAS -> Proxmox Host -> LXC -> Stash Container
```

Oder ganz konkret:

```text
/mnt/qnap-stash        -> Host
/mnt/stash-library     -> LXC
/data                  -> Docker-Container
```

## Warum dieser Ablauf für eine QNAP-Freigabe sinnvoll ist

Für NAS-gebundene Bibliotheken ist der sauberste Weg in Proxmox normalerweise:

1. NAS-Freigabe **auf dem Proxmox-Host mounten**
2. im CT mit **Advanced -> Mount Filesystems** nach `/mnt/stash-library` durchreichen
3. in Stash unter **Settings -> Library** den Pfad `/data` hinzufügen und speichern

Der Vorteil dieses Modells:

- die NAS-Anbindung wird an **einer** Stelle verwaltet, nämlich auf dem Proxmox-Host
- der LXC bekommt nur ein normales Verzeichnis durchgereicht
- Stash selbst sieht nur noch den internen Containerpfad `/data`
- spätere Änderungen an NFS oder SMB/CIFS betreffen nicht die Docker-Compose-Logik

## Beispiel mit QNAP und Proxmox-Bind-Mount

Angenommen, deine QNAP-Freigabe heißt `Multimedia` und wird auf dem Proxmox-Host unter folgendem Pfad eingebunden:

```text
/mnt/qnap-stash
```

Dann sollte der Container diesen Pfad so erhalten:

- **Host path:** `/mnt/qnap-stash`
- **Container path:** `/mnt/stash-library`

In der Compose-Datei wird daraus:

- **LXC path:** `/mnt/stash-library`
- **Stash path:** `/data`

Danach trägst du in Stash selbst **nur** diesen Pfad ein:

```text
/data
```

## Erster Start von Stash

Nach erfolgreicher Installation:

1. Browser öffnen
2. Stash unter `http://<CT-IP>:9999` aufrufen
3. **Settings -> Library** öffnen
4. `/data` hinzufügen
5. **Save** klicken
6. einen Scan starten

## Was Stash mit dem Library-Pfad macht

Laut Stash-Dokumentation dient der Bereich **Library** dazu, Verzeichnisse hinzuzufügen oder zu entfernen, die von Stash erkannt werden sollen. Diese Verzeichnisse werden für das Scannen neuer Dateien und zum Aktualisieren der Dateipfade in der Stash-Datenbank verwendet.

Die Verzeichnisse lassen sich getrennt für folgende Typen setzen:

- Videos
- Images
- Both

Wichtig: Nach Änderungen an den Verzeichnissen muss **Save** geklickt werden.

## Excluded Patterns / Ausschlussmuster

Stash unterstützt Ausschlussmuster per **Regex**. Dateien, deren Pfad oder Dateiname auf das Muster passt, werden beim Scan nicht in die Datenbank aufgenommen. Auch beim Clean-Task können sie wieder entfernt werden.

Beispiele aus der Praxis:

```text
sample.mp4$
```

Schließt alle Dateien aus, die auf `sample.mp4` enden.

```text
^/data/exclude/
```

Schließt ein bestimmtes Verzeichnis unterhalb deiner eingebundenen Bibliothek aus.

```text
/\.[[:word:]]+/
```

Schließt versteckte Verzeichnisse aus.

## Empfohlene Einstellungen für NAS- oder Netzwerkspeicher

### 1. Hashing: eher `oshash` als `MD5`

Stash unterstützt laut Doku zwei Hash-Verfahren für Videos:

- `oshash`
- `MD5`

`MD5` liest die **gesamte Datei**, was bei Dateien auf Netzlaufwerken langsam sein kann. `oshash` liest dagegen nur **64 KB am Anfang und 64 KB am Ende** der Datei. Für Bibliotheken auf einer QNAP- oder anderen NAS ist `oshash` daher in vielen Fällen die bessere Wahl.

### 2. Parallel Scan/Generation konservativ wählen

Stash dokumentiert, dass die Einstellung für parallele Scan-/Generierungsaufgaben besonders bei **remote/cloud filesystems** relevant ist. Wenn die Medien nicht lokal auf einer SSD liegen, sondern auf einer NAS, ist es oft besser, die Parallelität nicht unnötig hoch zu setzen.

Praxisbeispiel:

- kleiner NUC + alte QNAP + 1 Gbit LAN -> eher konservativ beginnen
- zuerst Standardwert testen
- nur bei Bedarf schrittweise erhöhen

## Rolle von StashDB

StashDB ist **keine Installationsvoraussetzung** für Stash selbst. Laut StashDB-Richtlinien ist StashDB eine öffentliche Instanz der Stash-Box-Software und dient als **Metadatenquelle** für Szenen, Studios und Performer. Video-Dateien selbst werden dort nicht gehostet.

Für dieses Repository ist StashDB also nur am Rand relevant; die eigentliche Installation basiert auf Proxmox Community Scripts, Docker und der Stash-Dokumentation.

## Quellen

### Proxmox Community Scripts

- Docs: https://community-scripts.org/docs
- GitHub: https://github.com/community-scripts/ProxmoxVE
- Docker CT Script: https://github.com/community-scripts/ProxmoxVE/blob/main/ct/docker.sh
- Docker Install Script: https://github.com/community-scripts/ProxmoxVE/blob/main/install/docker-install.sh

### Stash

- Stash Docker Docs: https://docs.stashapp.cc/installation/docker/
- Stash Configuration Docs: https://docs.stashapp.cc/in-app-manual/configuration/
- Stash GitHub Repo: https://github.com/stashapp/stash
- Official Docker README: https://github.com/stashapp/stash/blob/develop/docker/production/README.md
- Official Docker Compose example: https://github.com/stashapp/stash/blob/develop/docker/production/docker-compose.yml
- Manual sources: https://github.com/stashapp/stash/tree/master/ui/v2.5/src/docs/en/Manual

### StashDB

- What is StashDB?: https://guidelines.stashdb.org/docs/faq_getting-started/stashdb/what-is-stashdb/
