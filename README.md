# StashApp on Proxmox LXC (Community-Scripts style)

This repository contains a Community-Scripts-style container script and install script for deploying **StashApp** on **Proxmox VE** in an **LXC**.

## Files

- `ct/stashapp.sh` — host-side Proxmox CT creation/update script
- `install/stashapp-install.sh` — guest-side installation script

## Intended install flow

Run this from the Proxmox shell after the files are published to your GitHub repo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Nanja-at-web/StashAtProxmox/main/ct/stashapp.sh)"
```

## Recommended deployment pattern

For NAS-backed libraries, mount the NAS **on the Proxmox host** and pass it into the LXC with **Advanced > Mount Filesystems**.

Recommended path inside the container:

```text
/mnt/stash-library
```

The install script will ask for the library path and defaults to `/mnt/stash-library`.
The Docker Compose file then maps that path to `/data` inside the Stash container.

After first login to Stash, add this library path in the UI:

```text
/data
```

## Example Proxmox bind mount

If your host mounts the NAS at `/mnt/qnap-stash`, add a bind mount in the CT so that:

- host path: `/mnt/qnap-stash`
- container path: `/mnt/stash-library`

## First-run notes inside Stash

1. Open `http://<CT-IP>:9999`
2. Go to **Settings > Library**
3. Add `/data`
4. Click **Save**
5. Run a scan

## Suggested tuning for network storage

- Prefer **oshash** over MD5 for better performance on remote storage.
- Keep scan/generation parallelism conservative if the NAS is slow.
- Use excluded patterns to skip sample files, hidden folders, or unwanted directories.

## Suggested follow-up improvements

- add configurable port support
- add optional reverse proxy support
- add optional hardware transcoding device passthrough
- add optional environment file instead of inline compose values
- add an addon variant for installing on top of an existing Docker CT
