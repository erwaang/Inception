*This project has been created as part of the 42 curriculum by egaudich.*

# Inception

## Description

Inception is a system administration project whose goal is to deploy a small
web infrastructure entirely through Docker, with every image built from
scratch (no pre-built images except the base Alpine/Debian layer). The stack
reproduces a realistic self-hosted WordPress setup:

- **NGINX** — the single entry point to the infrastructure, serving HTTPS
  (TLSv1.2/TLSv1.3 only) on port 443.
- **WordPress + php-fpm** — the application layer, with no web server bundled
  in the container (NGINX proxies PHP requests to it over FastCGI).
- **MariaDB** — the database layer, dedicated to storing the WordPress data.

Each service runs in its own container, built from its own Dockerfile, and
all three communicate over a dedicated Docker bridge network. Two named
Docker volumes persist the WordPress files and the MariaDB database on the
host, under `/home/egaudich/data`.

## Instructions

### Requirements

- A Linux virtual machine with Docker and Docker Compose installed.
- `make`.

### Setup

1. Copy `srcs/.env.example` to `srcs/.env` (gitignored) and fill in real
   values for `DOMAIN_NAME`, `MYSQL_DATABASE`, `MYSQL_USER`, `WP_TITLE`,
   `WP_ADMIN_USER`, `WP_ADMIN_EMAIL`, `WP_USER`, `WP_USER_EMAIL`.
2. Copy each `secrets/*.txt.example` file to the matching `secrets/*.txt`
   (gitignored) and replace the placeholder values with real passwords:
   - `db_password.txt`
   - `db_root_password.txt`
   - `credentials.txt` (defines `WP_ADMIN_PASSWORD` and `WP_USER_PASSWORD`)
3. Add `127.0.0.1 egaudich.42.fr` (or your VM's IP) to `/etc/hosts` on the
   machine you browse from.

### Build and run

```sh
make        # builds the images and starts the stack
make down   # stops and removes the containers
make clean  # down + prune dangling Docker resources
make fclean # full teardown, including volumes and host data
```

See [DEV_DOC.md](DEV_DOC.md) for more details on the development workflow
and [USER_DOC.md](USER_DOC.md) for day-to-day usage.

## Project description — Docker design choices

The whole infrastructure is described in a single `docker-compose.yml`
(`srcs/docker-compose.yml`), which builds three custom Dockerfiles
(`srcs/requirements/{nginx,wordpress,mariadb}`) and wires them together on a
dedicated bridge network, with two named volumes for persistent data and a
Docker secrets mechanism for credentials.

**Virtual Machines vs Docker** — A VM virtualizes an entire hardware stack
and runs a full guest OS, which gives strong isolation but costs memory,
disk, and boot time. A Docker container shares the host kernel and only
packages the application plus its userland dependencies, which makes it far
lighter and faster to start, at the cost of weaker isolation than a VM. This
project uses one VM as the host (as required) and Docker containers inside
it to isolate each service (NGINX, WordPress, MariaDB) without the overhead
of three separate VMs.

**Secrets vs Environment Variables** — Environment variables declared in
`.env`/`docker-compose.yml` end up readable in `docker inspect`, in the
container's `/proc/<pid>/environ`, and in process listings, which is fine for
non-sensitive configuration (domain name, database name, usernames) but not
for passwords. Docker secrets are mounted as files under `/run/secrets/` at
runtime, are never baked into an image layer, and are not exposed by
`docker inspect`. This project uses `.env` for configuration values and
Docker secrets for the MariaDB passwords and the WordPress admin/user
passwords.

**Docker Network vs Host Network** — `network: host` makes a container share
the host's network namespace directly, which is simple but removes
isolation and can create port conflicts. A dedicated Docker bridge network
(used here, named `inception`) gives each container its own network
namespace and a private DNS so services can address each other by name
(e.g. `wordpress:9000`, `mariadb:3306`), while only NGINX publishes a port
(443) to the host. This matches the subject's requirement of NGINX being the
only entry point.

**Docker Volumes vs Bind Mounts** — A bind mount maps an arbitrary host path
directly into a container, with the host's filesystem permissions and no
indirection. A named volume is managed by Docker, decoupled from the
specific host path, and portable across setups. The subject requires named
volumes whose data physically lives under `/home/egaudich/data`; this is
achieved with named volumes using a `local` driver with `bind` driver
options pointing at that path — they remain Docker-managed named volumes
(visible via `docker volume ls`), not raw bind mounts in the compose file.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WordPress CLI (wp-cli) handbook](https://developer.wordpress.org/cli/commands/)
- [MariaDB server documentation](https://mariadb.com/kb/en/documentation/)
- [Docker secrets documentation](https://docs.docker.com/engine/swarm/secrets/)

### AI usage

AI assistance (Claude) was used to:
- Review the final project structure (Dockerfiles, `docker-compose.yml`,
  entrypoint scripts) against the subject's requirements and point out gaps
  (missing/empty documentation files, an empty MariaDB config file).
- Help draft this README and the `USER_DOC.md` / `DEV_DOC.md` files based on
  the existing configuration, which was written and understood by the
  author beforehand.
- Fill in the MariaDB `50-server.cnf` configuration file.

All generated content was reviewed and understood before being kept; the
Dockerfiles, entrypoint scripts, and `docker-compose.yml` logic were written
by hand.
