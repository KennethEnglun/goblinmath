#!/bin/sh
# PvP server container entrypoint:
#   1. Godot match server on loopback:9124 (restarted if it ever exits)
#   2. nginx in the foreground on 9123, answering /healthz for Railway's
#      edge and forwarding WebSocket upgrades to Godot.
set -e

( while true; do
	PORT=9124 /app/server.x86_64 --pvp-server --headless || true
	sleep 2
done ) &

exec nginx -g 'daemon off;'
