# stacks: my local dev infrastructure

One repo that sets up my everyday local tools in Docker: a reverse proxy, a start page,
Docker management, and one shared MariaDB and Postgres for all projects. Every tool
gets a friendly address like **http://zzport.com** instead of `localhost:9000`.

On a new laptop: install Docker, clone this repo, run `make setup`. That's it.

---

## What's inside and why

| Folder | Address | What it is | Why I want it |
| --- | --- | --- | --- |
| `traefik` | http://zztraefik.com | **Reverse proxy**. Sits on port 80 and forwards each domain to the right container. | Lets every app have a name instead of a port number, and no port clashes between projects. **Required**: everything else goes through it. |
| `traefik-home` | http://zzthome.com | **Start page** with a card for every running tool. | One bookmark to find everything. |
| `portainer` | http://zzport.com | **Docker web UI**: containers, logs, volumes, shells. | Easier than the terminal for poking around. |
| `mariadb` | `zzmariadb.com:3306` | **One shared MariaDB (MySQL)** server. | One database server for every PHP/Laravel/WordPress project instead of one per project. Saves RAM and setup. |
| `postgres` | `zzpgdb.com:5432` | **One shared PostgreSQL** server. | Same idea, for projects that use Postgres. |
| `mariadb-admin` | http://zzpma.com, http://zzdbmanager.com | **phpMyAdmin**, plus a tiny form that creates a database + user in one click. | Browse/import data, and set up a new project's DB in seconds. Adapted from [simple-phpadminer-mariadb-docker](https://github.com/anil3a/simple-phpadminer-mariadb-docker). |
| `pdf-filler` | http://zzpdffiller.com | **PDF form mapping UI** from [python-pdf-filler](../ai-repos/python-pdf-filler), built from source. | Map form fields to CSV columns or fixed values in the browser. Optional: needs that repo cloned next to this one (see [Using pdf-filler](#using-pdf-filler)). |

### How a request flows

```
browser: http://zzport.com
   │  /etc/hosts says zzport.com = 127.0.0.1 (this laptop)
   ▼
Traefik (port 80) ── reads the Host name, finds the container whose label says
   │                 Host(`zzport.com`)
   ▼
portainer container (port 9000, never exposed directly)
```

Containers don't publish their own ports. They join a shared Docker network called
`proxy` and tell Traefik their domain with **labels** in their `compose.yaml`.

> The `zz*.com` names only exist on this laptop. They are not real websites, and only
> work because `/etc/hosts` points them at `127.0.0.1`.

---

## First-time setup (new laptop)

### 1. Install the prerequisites

| Tool | How | Check |
| --- | --- | --- |
| Docker Desktop | https://www.docker.com/products/docker-desktop/, then open it once | `docker info` |
| git + make | macOS: `xcode-select --install` | `git --version && make --version` |

### 2. Clone the repo

```sh
mkdir -p ~/Projects/personal && cd ~/Projects/personal
git clone https://github.com/anil3a/stacks.git
cd stacks
```

### 3. (Moving from an old laptop?) Bring your secrets and data

Skip this on a brand-new install. Otherwise copy these from the old laptop
(see [Moving to a new laptop](#moving-to-a-new-laptop)):

- `mariadb/.env` and `postgres/.env`: database passwords
- `backups/`: database dumps

### 4. Run setup

```sh
make setup
```

This does, in order:

1. **checks** Docker is running
2. **adds the domains to `/etc/hosts`**: asks for your Mac password, keeps a backup at `/etc/hosts.bak`
3. **creates `.env` files** with random passwords (only if they don't exist yet)
4. **creates the `proxy` network** and **starts every stack**

The first run downloads images, so give it a few minutes.

### 5. Open it

- Go to **http://zzthome.com**. You should see cards for everything.
- Open **http://zzport.com** and **create the Portainer admin user within 5 minutes**.
  Portainer locks itself after that for safety; run `make portainer` to unlock.

### 6. (Moving laptops) Restore your databases

```sh
make restore-mariadb
make restore-postgres
```

---

## Everyday commands

Run `make` (or `make help`) to see them all.

| Command | What it does |
| --- | --- |
| `make up` | start everything (safe to run any time; only changes what's needed) |
| `make down` | stop everything. **Your data is kept.** |
| `make ps` | what's running |
| `make logs s=traefik` | follow one stack's logs (Ctrl+C to quit) |
| `make portainer` | (re)start just one stack, using any folder name |
| `make pull && make up` | update to newer images |
| `make backup` | dump all databases into `backups/` |

---

## Using the databases

| From | MariaDB | Postgres |
| --- | --- | --- |
| Your Mac (TablePlus, DBeaver, CLI) | host `zzmariadb.com` port `3306` | host `zzpgdb.com` port `5432` |
| Another container on the `proxy` network | host `mariadb` port `3306` | host `postgres` port `5432` |
| Admin user | `root` | `postgres` |
| Password | in `mariadb/.env` | in `postgres/.env` |

**Give each project its own database and user**, not root:

- MariaDB: open http://zzdbmanager.com and fill in the form.
- Postgres:
  ```sh
  docker exec -it postgres psql -U postgres \
    -c "CREATE ROLE myapp LOGIN PASSWORD 'secret';" \
    -c "CREATE DATABASE myapp OWNER myapp;"
  ```

> **Why do the databases use ports when the websites don't?** Traefik picks the container by
> reading the website name from each HTTP request. Database connections don't send that
> name, so each database gets its own port (3306, 5432) on Traefik and the domain just
> resolves to this laptop. That works because there's exactly one MariaDB and one Postgres.

---

## Using pdf-filler

Needs the python-pdf-filler repo at `~/Projects/personal/ai-repos/python-pdf-filler`
(`make up` builds the image from it). Without it, remove `pdf-filler` from `STACKS` in the
`Makefile`, or `make up` / `make setup` stop at that step.

It runs the hosted app (`pdf-filler serve`): accounts, shared folios, signatures and an
activity log, at http://zzpdffiller.com (and http://pdf.zz.home.arpa over Tailscale).

1. `make pdf-filler`.
2. Create your account once: `make pdf-user u=<name>` (it asks for the password twice).
   Sign-up stays closed; invite other people from a folio with an invite link (one use,
   7 days), which lets them create their own account.
3. Open http://zzpdffiller.com and log in.

Everything it stores (database, uploaded forms and data, mappings, signatures) is in
`pdf-filler/app-data/` (git-ignored). Back that folder up to keep it. Optional settings go in
`pdf-filler/.env` (see `pdf-filler/.env.example`), e.g. a seal key for the activity log.
The old single-user mapping files in `pdf-filler/data/` are not used any more.

The pages are plain HTTP here: fine on this Mac and over Tailscale (encrypted), but don't
publish it to the internet without HTTPS in Traefik and `PDF_FILLER_COOKIE_SECURE=1`.

## Adding a new app

Create a folder, e.g. `myapp/compose.yaml`:

```yaml
name: myapp

services:
  myapp:
    image: nginx:alpine          # your image
    restart: unless-stopped
    networks: [proxy]
    labels:
      - traefik.enable=true
      - traefik.http.routers.myapp.rule=Host(`zzmyapp.com`)
      - traefik.http.routers.myapp.entrypoints=web
      - traefik.http.services.myapp.loadbalancer.server.port=80   # port INSIDE the container
      # optional: show on the start page
      - traefik.home=true
      - traefik.home.category=Apps
      - traefik.home.alias=My App
      - traefik.home.description=What it does
      - traefik.home.image=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/nginx.svg

networks:
  proxy:
    external: true
```

Then:

1. Add `zzmyapp.com` to the `127.0.0.1` line in `hosts.txt` and run `make hosts`.
2. Add `myapp` to the `STACKS` list at the top of the `Makefile`.
3. `make myapp`. It appears on the start page within 30 seconds.

`myapp` must be unique per app in the router and service label names.

---

## Removing a stack

Everything except `traefik` is optional.

| Stack | Safe to remove? | Notes |
| --- | --- | --- |
| `traefik` | **No** | Every web address goes through it. |
| `traefik-home` | Yes | Just the start page. |
| `portainer` | Yes | |
| `mariadb` | Yes | **Also remove `mariadb-admin`**, which needs it. |
| `postgres` | Yes | |
| `mariadb-admin` | Yes | |
| `pdf-filler` | Yes | Saved mappings are in `pdf-filler/data/` (plain files, not a volume). |

### Just switch it off for now

```sh
docker compose -f portainer/compose.yaml down    # stop it
make portainer                                    # start it again later
```

`make up` will start it again, so for a longer break also do step 2 below.

### Remove it for good

1. **Back up first** if it holds data: `make backup`
2. **Stop it:** `docker compose -f portainer/compose.yaml down`
   - To **also delete its data**, add `-v`: `docker compose -f portainer/compose.yaml down -v`.
     **This cannot be undone.**
3. **Delete it from `STACKS`** at the top of the `Makefile`.
4. **Delete its domain** from `hosts.txt`, then run `make hosts`.
5. Optionally delete the folder: `rm -r portainer` (and commit).

If you remove `mariadb` or `postgres`, you can also remove its port lines (`3306` / `5432`
and the matching `--entrypoints...` line) from `traefik/compose.yaml` to free the port.

---

## Moving to a new laptop

Images and config come from git, but **data and passwords don't**. Those live in Docker volumes
and in the ignored `.env` files.

On the **old** laptop:

```sh
make backup     # writes backups/mariadb.sql and backups/postgres.sql
```

Copy to the new laptop (AirDrop, USB, a private cloud folder):

```
backups/
mariadb/.env
postgres/.env
pdf-filler/.env
pdf-filler/data/
```

Keep the `.env` files. The dumps include the database users, so restoring with
different `.env` passwords means `make backup`/`restore` and the admin tools can't log in.

On the **new** laptop, put them back in the cloned repo, then run `make setup`,
`make restore-mariadb` and `make restore-postgres`.

Portainer settings aren't backed up. Just create the admin user again.

---

## Phone / other devices via Tailscale

`/etc/hosts` only affects this laptop, so `zzport.com` won't open on your phone. Every app
therefore also has a **tailnet name** under `zz.home.arpa` (a name reserved for home
networks, so it never clashes with a real website):

| App | On this laptop | On any Tailscale device |
| --- | --- | --- |
| Start page | http://zzthome.com | http://home.zz.home.arpa |
| Traefik | http://zztraefik.com | http://traefik.zz.home.arpa |
| Portainer | http://zzport.com | http://port.zz.home.arpa |
| phpMyAdmin / DB manager | http://zzpma.com, http://zzdbmanager.com | http://pma.zz.home.arpa, http://dbmanager.zz.home.arpa |
| PDF Filler | http://zzpdffiller.com/?token=... | http://pdf.zz.home.arpa/?token=... |
| MariaDB / Postgres | zzmariadb.com:3306, zzpgdb.com:5432 | mariadb.zz.home.arpa:3306, pgdb.zz.home.arpa:5432 |

A small DNS server (`tailscale-dns/`, CoreDNS) answers every `*.zz.home.arpa` name with
this Mac's Tailscale IP, and Tailscale sends only those lookups to it (split DNS).

One-time setup:

1. Install Tailscale on the Mac and the phone, signed in to the **same tailnet**, and make
   sure the Mac shows as connected.
   In Docker Desktop, open **Settings** > **Advanced**, turn on **Allow privileged port
   forwarding to external machines**, then **Apply & restart**. Without it Docker can't
   open port 53 on the Tailscale address.
2. `make tailscale-dns`. It reads the Mac's Tailscale IP (`100.x.y.z`), writes
   `tailscale-dns/.env` and starts the DNS container on that address only (not on your
   Wi-Fi). It prints the IP.
3. In the Tailscale admin console (login.tailscale.com): **DNS** > **Nameservers** >
   **Add nameserver** > **Custom**, enter that IP, turn on **Restrict to domain** (split
   DNS) and type `zz.home.arpa`. Save.
4. On the phone open http://pdf.zz.home.arpa/?token=... with the same token as in
   `make logs s=pdf-filler`, only the host changed to `pdf.zz.home.arpa`.

To check it from the phone or another tailnet device: `nslookup pdf.zz.home.arpa` (or a
DNS app on the phone) should answer with the Mac's `100.x.y.z` address. On the Mac,
`docker ps -f name=tailscale-dns` shows whether the DNS container runs (`make ps` lists
only containers on the proxy network, so it doesn't show this one).

**After a reboot or a Docker Desktop restart:** if Docker starts before Tailscale is
connected, the DNS container can't use the Tailscale address yet, fails, and Docker doesn't
retry. If the phone suddenly can't open the `zz.home.arpa` names, connect Tailscale on the
Mac and run `make tailscale-dns` again.

Notes:
- Anyone on your tailnet can reach these apps (the admin tools have no extra login; PDF
  Filler still needs its token). Share the tailnet only with your own devices.
- The start page's cards link to the laptop names, so on the phone type the tailnet names
  above instead.
- If the Mac's Tailscale IP ever changes, run `make tailscale-dns` again and update the
  nameserver in the admin console. Stop it with
  `docker compose -f tailscale-dns/compose.yaml down` (`make down` doesn't touch it).
- macOS may ask whether Docker can accept incoming connections; allow it, or the phone
  gets no answer.
- If Docker Desktop refuses to publish on the Tailscale address at all, change the two
  `ports:` lines in `tailscale-dns/compose.yaml` to `"53:53/udp"` and `"53:53/tcp"`. That
  also answers on your Wi-Fi/LAN, which is still harmless (it only answers
  `zz.home.arpa` names, with the Tailscale address) but is no longer Tailscale-only.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Address doesn't load at all | Is it in `/etc/hosts`? `cat /etc/hosts`, then `make hosts`. Flush DNS: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| Browser shows a security / HTTPS error | Type `http://` explicitly. This setup is HTTP only. |
| `404 page not found` | Traefik is up but the container isn't, or its label has a typo. Check http://zztraefik.com → HTTP Routers, and `make ps`. |
| `make up` fails: port 80/3306/5432 already in use | Something else is using it (e.g. a Homebrew MySQL). Find it with `lsof -nP -iTCP:3306 -sTCP:LISTEN` and stop it. |
| Portainer says the instance timed out | `make portainer`, then create the admin user within 5 minutes. |
| New app missing from the start page | Wait 30 s; check it has `traefik.home=true`, `traefik.home.category` and `traefik.home.alias`. |
| Forgot a database password | It's in `mariadb/.env` or `postgres/.env`. |
| `make tailscale-dns` says "bind: can't assign requested address" (or "cannot assign requested address") | Tailscale isn't connected on the Mac, or its IP changed. Connect Tailscale and run `make tailscale-dns` again. |
| `make tailscale-dns` says "Cannot bind privileged port 53" | In Docker Desktop: **Settings** > **Advanced** > turn on **Allow privileged port forwarding to external machines**, Apply & restart. Then `docker compose -f tailscale-dns/compose.yaml down` and `make tailscale-dns` again. |
| Phone can't open `*.zz.home.arpa` after a reboot | The DNS container started before Tailscale. Connect Tailscale, then `make tailscale-dns`. |

---

## Notes and quirks

- **traefik-home** uses the 2017 image `lobre/traefik-home`, which only understands old
  Traefik v1 labels and only exists for Intel CPUs (it runs emulated on Apple Silicon).
  `traefik-home/home.tmpl` replaces its page so it reads the current labels, and
  `traefik-home/Procfile` makes it refresh every 30 s because it can't read events from
  Docker 29+.
- **Big SQL imports:** `mariadb/conf/large-imports.cnf` (6 GB buffer pool) is off by default.
  Uncomment its line in `mariadb/compose.yaml`, and first raise Docker Desktop's memory
  limit (Settings → Resources).
- The admin tools (Portainer, phpMyAdmin, DB manager) have no extra login in front of
  them, and the ports listen on all network interfaces. That's fine on a home network or
  Tailscale. On public Wi-Fi, consider `make down`. Binding Traefik's ports to
  `127.0.0.1` in `traefik/compose.yaml` also hides them from the LAN, but turns off phone
  access over Tailscale too; to keep it, bind to `127.0.0.1` and the Mac's Tailscale IP
  (two lines per port, e.g. `"127.0.0.1:80:80"` and `"100.x.y.z:80:80"`).
