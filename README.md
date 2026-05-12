# Grimmory Proxmox VE LXC script

Unofficial Proxmox VE helper script for [Grimmory](https://github.com/grimmory-tools/grimmory) (the community fork of the discontinued BookLore project), structured to mirror the [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE) framework.

This script exists because the community-scripts maintainers [declined](https://github.com/community-scripts/ProxmoxVE/discussions/13155) to ship a Grimmory script and removed the previous BookLore script when the upstream project shut down.

## Usage

From a Proxmox VE host shell:

```sh
bash -c "$(wget -qLO - https://raw.githubusercontent.com/andersonimes/grimmory-proxmoxve/main/ct/grimmory.sh)"
```

The same invocation handles:

- **Fresh install** — creates a new Debian 13 unprivileged LXC, installs Java 25 + Node 22 + MariaDB, builds Grimmory from source, sets up systemd.
- **In-place update / migration** — when run against an existing LXC that contains a BookLore install at `/opt/booklore` or a Grimmory install at `/opt/grimmory`, it stops the service, backs up the install (with rollback retained on failure), rebuilds from the latest Grimmory release, and renames `booklore.service` → `grimmory.service`.

## What gets migrated from BookLore

- Env-var renames (`BOOKLORE_DATA_PATH` → `APP_PATH_CONFIG`, `BOOKLORE_BOOKDROP_PATH` → `APP_BOOKDROP_FOLDER`; removes `BOOKLORE_BOOKS_PATH` and `BOOKLORE_PORT`; injects `SERVER_PORT=6060`)
- kepubify relocated from `/opt/booklore_storage/data/tools/kepubify` to `/usr/local/bin/kepubify`
- systemd unit renamed, JVM flags refreshed (`--enable-preview`, `XX:+UseCompactObjectHeaders`)
- Nginx purged if still present (BookLore ≤2.0 ran behind it; Grimmory does not)
- `/opt/booklore_storage/` data directory **kept in place** — the path is deliberately not renamed, to match the migration pattern documented in [Grimmory issue discussions](https://github.com/orgs/grimmory-tools/discussions/120) and avoid breaking config references.
- MariaDB schema `booklore_db` kept in place (Grimmory continues BookLore's Flyway/Liquibase migration chain).

## Defaults

| Setting | Value |
|---|---|
| OS | Debian 13 |
| Privileged | unprivileged |
| CPU | 3 cores |
| RAM | 3 GB |
| Disk | 10 GB |
| Port | 6060 |

Override at invocation: `var_disk=20 bash -c "$(wget ...)"`

## Credits

- Originally based on the BookLore script by [MickLesk / community-scripts](https://github.com/community-scripts/ProxmoxVE)
- Booklore → Grimmory migration logic adapted from [dalenjohnson's gist](https://gist.github.com/databoy2k/1ef8c9ccf93d94d6ac776fa1befb182e)
- Repackaged as a maintained fork here

Licensed MIT, matching upstream.
