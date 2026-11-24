# ---------------------------------------------------------------------------
# Local Docker stacks. Run `make help` to see every command.
#
# STACKS is the list of folders to manage, in start order. To stop using one,
# delete it from this list (see README "Removing a stack"). Override for a
# single run with:  make up STACKS="traefik portainer"
# ---------------------------------------------------------------------------
STACKS ?= traefik traefik-home portainer mariadb postgres mariadb-admin pdf-filler

# Same list, reversed, for shutting down (works on macOS and Linux)
REVERSED := $(shell echo $(STACKS) | awk '{for (i=NF; i>0; i--) printf "%s ", $$i}')
BACKUP_DIR := backups
# The Tailscale CLI: on PATH, or inside the Mac app
TAILSCALE ?= $(shell command -v tailscale 2>/dev/null || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)

.DEFAULT_GOAL := help
.PHONY: help setup check up down restart pull ps logs network env hosts tailscale-dns pdf-user \
        backup restore-mariadb restore-postgres $(STACKS)

help: ## show this help
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-18s %s\n", $$1, $$2}'

setup: check hosts up ## first time on a new machine: check Docker, add hosts, start everything
	@echo "\nDone. Open http://zzthome.com"

check: ## check that Docker is installed and running
	@command -v docker >/dev/null || { echo "Docker is not installed. See README step 1."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Docker is installed but not running. Start Docker Desktop and retry."; exit 1; }
	@docker compose version >/dev/null || { echo "docker compose plugin missing."; exit 1; }
	@echo "Docker OK"

up: network env ## start all stacks
	@for s in $(STACKS); do echo "==> $$s"; docker compose -f $$s/compose.yaml up -d --build || exit 1; done

down: ## stop all stacks (your data in volumes is kept)
	@for s in $(REVERSED); do echo "==> $$s"; docker compose -f $$s/compose.yaml down; done

restart: down up ## stop then start everything

pull: ## download newer images (then run `make up` to use them)
	@for s in $(STACKS); do docker compose -f $$s/compose.yaml pull; done

ps: ## list running containers
	@docker ps --filter network=proxy --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

logs: ## follow one stack's logs: make logs s=traefik
	docker compose -f $(s)/compose.yaml logs -f

$(STACKS): network env
	docker compose -f $@/compose.yaml up -d --build

network:
	@docker network inspect proxy >/dev/null 2>&1 || docker network create proxy

env: ## create missing .env files with random passwords
	@for s in mariadb postgres pdf-filler; do \
	  if [ -d $$s ] && [ ! -f $$s/.env ]; then \
	    sed "s/change-me/$$(openssl rand -hex 16)/" $$s/.env.example > $$s/.env && echo "created $$s/.env"; \
	  fi; \
	done

hosts: ## add/update the zz*.com names in /etc/hosts (asks for your password)
	@tmp=$$(mktemp); \
	sed '/# >>> stacks/,/# <<< stacks/d' /etc/hosts > $$tmp; \
	cat hosts.txt >> $$tmp; \
	if cmp -s $$tmp /etc/hosts; then echo "/etc/hosts already up to date"; \
	else sudo cp /etc/hosts /etc/hosts.bak && sudo sh -c "cat $$tmp > /etc/hosts" && echo "/etc/hosts updated (backup at /etc/hosts.bak)"; fi; \
	rm -f $$tmp

tailscale-dns: ## phone access over Tailscale: DNS for *.zz.home.arpa (README "Phone / other devices")
	@if ! "$(TAILSCALE)" status >/dev/null 2>&1; then echo "Tailscale is not running on this Mac. Open Tailscale, connect, then retry."; exit 1; fi; \
	ip=$$("$(TAILSCALE)" ip -4 2>/dev/null | head -1); \
	if [ -z "$$ip" ]; then echo "Tailscale has no IPv4 address yet. Wait a moment, then retry."; exit 1; fi; \
	echo "TAILSCALE_IP=$$ip" > tailscale-dns/.env; \
	docker compose -f tailscale-dns/compose.yaml up -d && \
	echo "DNS for *.zz.home.arpa answers $$ip. Now add $$ip as a nameserver for zz.home.arpa in the Tailscale admin console."

pdf-user: ## create a pdf-filler account: make pdf-user u=<name> (asks for the password)
	@test -n "$(u)" || { echo "usage: make pdf-user u=<name>"; exit 1; }
	docker exec -it pdf-filler pdf-filler users add "$(u)"

backup: ## dump all MariaDB + Postgres databases into ./backups
	@mkdir -p $(BACKUP_DIR)
	@if docker ps -q -f name=^mariadb$$ | grep -q .; then \
	  docker exec mariadb sh -c 'mariadb-dump -uroot -p"$$MARIADB_ROOT_PASSWORD" --all-databases --single-transaction --routines --events' > $(BACKUP_DIR)/mariadb.sql \
	  && echo "wrote $(BACKUP_DIR)/mariadb.sql"; fi
	@if docker ps -q -f name=^postgres$$ | grep -q .; then \
	  docker exec postgres sh -c 'pg_dumpall -U "$$POSTGRES_USER"' > $(BACKUP_DIR)/postgres.sql \
	  && echo "wrote $(BACKUP_DIR)/postgres.sql"; fi

restore-mariadb: ## load ./backups/mariadb.sql into MariaDB
	docker exec -i mariadb sh -c 'mariadb -uroot -p"$$MARIADB_ROOT_PASSWORD"' < $(BACKUP_DIR)/mariadb.sql

restore-postgres: ## load ./backups/postgres.sql into Postgres
	docker exec -i postgres sh -c 'psql -q -U "$$POSTGRES_USER" -d postgres' < $(BACKUP_DIR)/postgres.sql
