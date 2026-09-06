.PHONY: up down

up:
	cd /home/eloquent/elofyra/docker/jellyfin && sudo docker compose up -d
	cd /home/eloquent/elofyra/docker/navidrome && sudo docker compose up -d
	# cd /home/eloquent/elofyra/docker/portainer && sudo docker compose up -d
	# cd /home/eloquent/elofyra/docker/caddy && sudo docker compose up -d
	cd /home/eloquent/elofyra/docker/filebrowser && sudo docker compose up -d
	cd /home/eloquent/elofyra/docker/immich && sudo docker compose up -d

down:
	cd /home/eloquent/elofyra/docker/jellyfin && sudo docker compose down
	cd /home/eloquent/elofyra/docker/navidrome && sudo docker compose down
	cd /home/eloquent/elofyra/docker/portainer && sudo docker compose down
	# cd /home/eloquent/elofyra/docker/caddy && sudo docker compose down
	cd /home/eloquent/elofyra/docker/filebrowser && sudo docker compose down
	cd /home/eloquent/elofyra/docker/immich && sudo docker compose down
