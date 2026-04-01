#!/bin/bash
# Auto-restart wrapper for Vertex AI proxy
# Works on both Linux and macOS

kill_port() {
  if command -v fuser &>/dev/null; then
    fuser -k 4100/tcp 2>/dev/null
  else
    lsof -ti :4100 | xargs kill 2>/dev/null
  fi
}

kill_port
sleep 1

cd /opt/ocana/bifrost
export GOOGLE_APPLICATION_CREDENTIALS=/opt/ocana/openclaw/gcp-adc.json

while true; do
  kill_port
  sleep 1
  node proxy.js
  echo "Proxy exited at $(date), restarting in 3s..."
  sleep 3
done
