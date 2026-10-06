# Developer Documentation

This document describes how to set up, build, and work on the Inception
project as a developer.

## 1. Prerequisites

- A Linux virtual machine with Docker Engine and the Docker Compose plugin
  (`docker compose`, not the legacy `docker-compose` binary).
- `make`.
- A login matching the one hard-coded in the project (`egaudich`): it is
  used for the host data directory (`/home/egaudich/data`) and the domain
  name (`egaudich.42.fr`). Update the `Makefile`'s `LOGIN` variable, the
  `docker-compose.yml` volume `device:` paths, and `nginx.conf`'s
  `server_name` together if you fork this under a different login.

## 2. Configuration files to create (not versioned)

Templates are versioned so a fresh clone shows exactly what to fill in;
the real files are gitignored and must be created manually:

```sh
cp srcs/.env.example srcs/.env
cp secrets/db_password.txt.example secrets/db_password.txt
cp secrets/db_root_password.txt.example secrets/db_root_password.txt
cp secrets/credentials.txt.example secrets/credentials.txt
```

Then edit each copy:

### `srcs/.env`

```env
DOMAIN_NAME=egaudich.42.fr

MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user

WP_TITLE=Inception
WP_ADMIN_USER=<admin-username-without-admin-in-it>
WP_ADMIN_EMAIL=admin@egaudich.42.fr
WP_USER=<second-wordpress-user>
WP_USER_EMAIL=user@egaudich.42.fr
```

### `secrets/`

- `db_password.txt` — plain text password for `MYSQL_USER`.
- `db_root_password.txt` — plain text password for the MariaDB `root` user.
- `credentials.txt` — shell-sourceable file defining:
  ```sh
  WP_ADMIN_PASSWORD=...
  WP_USER_PASSWORD=...
  ```

`.gitignore` excludes `secrets/*` and `srcs/.env` (only the `*.example`
templates stay tracked) — the real files must never be committed.

## 3. Building and launching the project

The `Makefile` at the repository root drives everything; it never calls
`docker` directly except through `docker compose -f srcs/docker-compose.yml`.

```sh
make            # = make up: creates host data dirs, builds images, starts the stack
make up         # same as above
make down       # docker compose down (containers removed, volumes kept)
make stop       # docker compose stop
make start       # docker compose start
make logs       # docker compose logs -f
make ps         # docker compose ps
make clean      # down + `docker system prune -af`
make fclean     # down -v --rmi all + prune + rm -rf the host data dir
make re         # fclean + all
```

Each service is built from its own Dockerfile under
`srcs/requirements/<service>/`, from a `debian:bookworm` base, with no
`latest` tag and no pulled pre-built service image, per the subject's
constraints.

## 4. Useful commands for containers and volumes

```sh
docker compose -f srcs/docker-compose.yml ps                 # status/health
docker compose -f srcs/docker-compose.yml logs -f <service>  # follow one service
docker exec -it wordpress sh                                 # shell into a container
docker exec -it mariadb mariadb -uroot -p                     # SQL shell (prompts for root pwd)

docker volume ls                                              # list named volumes
docker volume inspect wordpress                                # see the volume's mountpoint
docker network inspect inception                               # inspect the bridge network
```

## 5. Where project data is stored and how it persists

- `wordpress` (named volume) → bind-backed by `local` driver options at
  `/home/egaudich/data/wordpress` on the host; holds the WordPress
  installation (core, themes, plugins, uploads). Mounted into both the
  `wordpress` container (read/write, PHP) and the `nginx` container
  (to serve static assets directly).
- `mariadb` (named volume) → bind-backed at `/home/egaudich/data/mariadb`;
  holds the full MySQL/MariaDB data directory.

Both are declared as Docker named volumes in `docker-compose.yml` using a
`local` driver with `driver_opts: {type: none, o: bind, device: ...}` — this
satisfies the subject's requirement that volume data lands under
`/home/egaudich/data` while keeping them real named volumes (as opposed to
inline bind mounts under the `volumes:` service key).

Data survives `make down`/`make stop`/`make start` and container restarts.
It is only destroyed by `make fclean` (which removes the volumes and the
host directory) or by manually running `docker volume rm`.

### Initialization flow

- `mariadb`'s entrypoint (`tools/init.sh`) only runs `mariadb-install-db` and
  creates the database/users the first time the volume is empty; on
  subsequent starts it skips straight to `exec mysqld --user=mysql`.
- `wordpress`'s entrypoint (`tools/setup.sh`) waits (bounded retries, not an
  infinite loop) for MariaDB to answer, then runs `wp core download`/
  `wp config create`/`wp core install`/`wp user create` only if
  `wp-config.php` doesn't already exist in the volume, before handing off to
  `exec php-fpm8.2 -F` (foreground, PID 1).
- `nginx` generates its self-signed TLS certificate at build time (not at
  runtime), then runs `nginx -g "daemon off;"` in the foreground.

This idempotency means re-running `make up` on an existing data volume does
not reinstall WordPress or recreate database users/content.
