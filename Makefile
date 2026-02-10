.PHONY: up

up:
	cd ~/elofyra/docker/jellyfin && sudo docker compose up -d
	cd ~/elofyra/docker/navidrome && sudo docker compose up -d
