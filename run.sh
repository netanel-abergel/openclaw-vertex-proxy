#!/bin/bash
while true; do
  cd /opt/ocana/bifrost
  GOOGLE_APPLICATION_CREDENTIALS=/opt/ocana/openclaw/gcp-adc.json node proxy.js
  echo "Proxy crashed at $(date), restarting in 2s..."
  sleep 2
done
