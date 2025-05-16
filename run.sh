#!/bin/bash
set -e
# prepare devcontainer container from appropriate repositories as staging images:
docker rmi jellyfin_backend_runner_stage:ice_master-amd64 || true

docker start jellyfin_backend_runner || true

# get rid bindings and use rigid dirs instead right inside containers tpo be able to commit them:
docker exec -u root jellyfin_backend_runner bash -c 'mkdir -p /opt/jellyfin-server; cp -a /workspaces/jellyfin-server/. /opt/jellyfin-server'
#
docker commit jellyfin_backend_runner jellyfin_backend_runner_stage:ice_master-amd64

docker compose -f ./compose.yml up --build --detach

docker rmi jellyfin_backend_runner_stage:ice_master-amd64


docker history --no-trunc --format '{{.ID}}\t{{.Size}}\t{{.CreatedBy}}' jellyfin/jellyfin:ice_master-amd64 | grep -v '	0B	' > size_report.txt

docker save -o 1.tar jellyfin/jellyfin:ice_master-amd64
scp -Or  1.tar root@192.168.13.1:/mnt/data2