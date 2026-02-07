.PHONY: help setup build start stop restart logs console console-server update status start-fastdl compress-maps upload-maps add-server start-server stop-server logs-server relay relay-stop relay-logs clean

help:
	@echo "TF2 Classified Docker Server"
	@echo ""
	@echo "  make setup         — Initial setup (creates dirs, .env)"
	@echo "  make build         — Build the Docker image"
	@echo "  make start         — Start the server"
	@echo "  make stop          — Stop the server"
	@echo "  make restart       — Restart the server (re-runs updates)"
	@echo "  make logs          — Tail server logs"
	@echo "  make console       — Attach to server console (Ctrl+B, D to detach)"
	@echo "  make update        — Update game files inside running container"
	@echo "  make status        — Show container status"
	@echo "  make start-fastdl  — Start with self-hosted FastDL"
	@echo "  make compress-maps — Compress maps in data/maps/ for FastDL"
	@echo "  make upload-maps   — Compress + upload maps to Cloudflare R2"
	@echo ""
	@echo "  WireGuard Relay:"
	@echo "  make relay         — Start with WireGuard tunnel (hides IP)"
	@echo "  make relay-stop    — Stop WireGuard relay setup"
	@echo "  make relay-logs    — Tail WireGuard + server logs"
	@echo ""
	@echo "  Multi-server:"
	@echo "  make add-server N=2      — Create dirs + .env for server N"
	@echo "  make start-server N=2    — Start server N"
	@echo "  make stop-server N=2     — Stop server N"
	@echo "  make logs-server N=2     — Tail logs for server N"
	@echo "  make console-server N=2  — Attach to console for server N"
	@echo ""
	@echo "  make clean         — Remove containers and images"
	@echo ""

setup:
	@chmod +x setup.sh && ./setup.sh

build:
	docker compose build

start:
	docker compose up -d

stop:
	docker compose down

restart:
	docker compose down && docker compose up -d

logs:
	docker compose logs -f

console:
	@echo "Attaching to srcds console. Press Ctrl+B, D to detach."
	docker compose exec tf2classified tmux attach -t srcds

console-server:
ifndef N
	@echo "Usage: make console-server N=2"
	@exit 1
endif
	@echo "Attaching to srcds console for server $(N). Press Ctrl+B, D to detach."
	docker compose exec tf2classified-$(N) tmux attach -t srcds

update:
	docker compose exec tf2classified /opt/scripts/update.sh

status:
	docker compose ps

start-fastdl:
	docker compose --profile fastdl up -d

compress-maps:
	@chmod +x scripts/compress-maps.sh
	@./scripts/compress-maps.sh

upload-maps:
	@chmod +x scripts/upload-fastdl.sh
	@./scripts/upload-fastdl.sh

add-server:
ifndef N
	@echo "Usage: make add-server N=2"
	@exit 1
endif
	@mkdir -p servers/$(N)/cfg servers/$(N)/addons/sourcemod/plugins servers/$(N)/addons/sourcemod/configs servers/$(N)/maps servers/$(N)/logs servers/$(N)/demos
	@if [ ! -f .env.server$(N) ]; then \
		cp .env.server2.example .env.server$(N); \
		RCON_PASS=$$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20); \
		sed -i "s/^RCON_PASSWORD=changeme$$/RCON_PASSWORD=$$RCON_PASS/" .env.server$(N); \
		sed -i "s/^SERVER_NAME=.*/SERVER_NAME=My TF2 Classified Server $(N)/" .env.server$(N); \
		PORT=$$((27014 + $(N))); \
		sed -i "s/^SERVER_PORT=.*/SERVER_PORT=$$PORT/" .env.server$(N); \
		echo "Created .env.server$(N) (port $$PORT, RCON: $$RCON_PASS)"; \
	else \
		echo ".env.server$(N) already exists, not overwriting"; \
	fi
	@if [ ! -f servers/$(N)/cfg/server_custom.cfg ]; then \
		printf '// Custom server settings for server $(N)\n// Loaded after server.cfg\n' > servers/$(N)/cfg/server_custom.cfg; \
	fi
	@echo ""
	@echo "Next:"
	@echo "  1. Edit .env.server$(N)"
	@echo "  2. Add server$(N) service to docker-compose.yml (copy tf2classified-2 block)"
	@echo "  3. docker compose --profile server$(N) up -d"

start-server:
ifndef N
	@echo "Usage: make start-server N=2"
	@exit 1
endif
	docker compose --profile server$(N) up -d

stop-server:
ifndef N
	@echo "Usage: make stop-server N=2"
	@exit 1
endif
	docker compose --profile server$(N) down

logs-server:
ifndef N
	@echo "Usage: make logs-server N=2"
	@exit 1
endif
	docker compose logs -f tf2classified-$(N)

RELAY_COMPOSE := docker compose -f docker-compose.yml -f docker-compose.wireguard.yml

relay:
	@if [ ! -f wireguard/wg0.conf ]; then \
		echo "Error: wireguard/wg0.conf not found."; \
		echo "Copy wireguard/wg0.conf.example → wireguard/wg0.conf and fill in your keys."; \
		exit 1; \
	fi
	$(RELAY_COMPOSE) up -d

relay-stop:
	$(RELAY_COMPOSE) down

relay-logs:
	$(RELAY_COMPOSE) logs -f

clean:
	docker compose down --rmi all
	@echo "Cleaned containers and images. Game data volumes preserved."
	@echo "To also remove game data: docker volume rm tf2classified-docker_tf2-data tf2classified-docker_classified-data"
