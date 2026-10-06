# User Documentation

This document explains how to use the Inception stack once it has been
deployed on the virtual machine: what it provides, how to start/stop it,
how to access it, and how to check that everything is running.

## 1. What services does the stack provide?

| Service    | Role                                                              |
|------------|--------------------------------------------------------------------|
| `nginx`    | Public entry point. Serves the site over HTTPS (TLSv1.2/1.3) on port 443. |
| `wordpress`| Runs the WordPress site via php-fpm (not reachable directly from outside). |
| `mariadb`  | Database engine storing all WordPress content (posts, users, settings). |

Data persists across restarts in two Docker named volumes:
- `wordpress` → WordPress files (themes, plugins, uploads, core).
- `mariadb` → the MySQL/MariaDB data directory.

Both are stored on the host under `/home/egaudich/data/`.

## 2. Starting and stopping the project

From the project root (where the `Makefile` is located):

```sh
make         # build (if needed) and start all services in the background
make stop    # stop the containers without removing them
make start   # restart previously stopped containers
make down    # stop and remove the containers (volumes are kept)
make fclean  # remove containers, images, volumes, and the host data directory
```

Check the current state at any time with:

```sh
make ps
```

## 3. Accessing the website and the admin panel

- Make sure `egaudich.42.fr` resolves to the VM's IP (add an entry to
  `/etc/hosts` on the machine you browse from if it isn't already set via
  DNS).
- **Website**: `https://egaudich.42.fr/`
- **Admin panel (wp-admin)**: `https://egaudich.42.fr/wp-admin/`

The browser will warn about the TLS certificate because it is
self-signed — this is expected for a local/VM setup; accept the exception to
continue.

## 4. Locating and managing credentials

Credentials are never stored in the Dockerfiles or in `docker-compose.yml`.
They live in two places, both excluded from Git:

- `srcs/.env` — non-sensitive configuration: domain name, database name,
  database username, WordPress titles/usernames/emails.
- `secrets/` (project root) — sensitive values, mounted into containers as
  Docker secrets:
  - `db_password.txt` — password of the WordPress database user.
  - `db_root_password.txt` — MariaDB root password.
  - `credentials.txt` — WordPress administrator and second-user passwords.

To change a password, edit the relevant file under `secrets/` and the
corresponding file in `srcs/.env`, then rebuild the affected container with
`make down && make`. Note: the database users are only created on the
*first* startup against an empty volume; changing a password afterwards
requires updating it directly in WordPress/MariaDB, or wiping the volume
with `make fclean` and restarting.

There are two WordPress users:
- An administrator account (username does not contain "admin"/"administrator").
- A regular author account.

## 5. Checking that services are running correctly

```sh
make ps        # shows the status/health of each container
make logs      # follow the logs of all services
docker logs nginx
docker logs wordpress
docker logs mariadb
```

All three containers are configured with `restart: unless-stopped`, so they
automatically come back up after a crash or a VM reboot (as long as Docker
itself is running). The `mariadb` service also exposes a healthcheck
(`mariadb-admin ping`) that `docker compose ps` reports as `healthy`/
`unhealthy`, and `wordpress` only starts once MariaDB reports healthy.
