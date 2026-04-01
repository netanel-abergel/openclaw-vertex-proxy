#!/bin/bash
# Vertex AI Proxy Controller for OpenClaw
# Usage: vertex-ctl {start|stop|status|model <name>}

PROXY_DIR="/opt/ocana/bifrost"
OC_CONF="/opt/ocana/openclaw/openclaw.json"
AGENT_MODELS="/opt/ocana/openclaw/agents/main/agent/models.json"
AUTH_PROFILES="/opt/ocana/openclaw/agents/main/agent/auth-profiles.json"
SESSIONS="/opt/ocana/openclaw/agents/main/sessions/sessions.json"
GCP_CREDS="/opt/ocana/openclaw/gcp-adc.json"

enable_proxy() {
  # Update baseUrl and apiKey without wiping existing fields (like models array)
  jq '(.models.providers.anthropic.baseUrl) = "http://localhost:4100" | (.models.providers.anthropic.apiKey) = "vertex-proxy"' "$OC_CONF" > /tmp/_oc.json && cp /tmp/_oc.json "$OC_CONF"
  jq '(.providers.anthropic.baseUrl) = "http://localhost:4100" | (.providers.anthropic.apiKey) = "vertex-proxy"' "$AGENT_MODELS" > /tmp/_am.json && cp /tmp/_am.json "$AGENT_MODELS"
  jq '.["anthropic:manual"] = {"provider":"anthropic","token":"vertex-proxy","profileId":"anthropic:manual"}' "$AUTH_PROFILES" > /tmp/_ap.json && cp /tmp/_ap.json "$AUTH_PROFILES"
}

disable_proxy() {
  jq '(.models.providers.anthropic.baseUrl) = "https://api.anthropic.com" | (.models.providers.anthropic.apiKey) = ""' "$OC_CONF" > /tmp/_oc.json && cp /tmp/_oc.json "$OC_CONF"
  jq '(.providers.anthropic.baseUrl) = "https://api.anthropic.com" | (.providers.anthropic.apiKey) = ""' "$AGENT_MODELS" > /tmp/_am.json && cp /tmp/_am.json "$AGENT_MODELS"
  jq 'del(.["anthropic:manual"])' "$AUTH_PROFILES" > /tmp/_ap.json && cp /tmp/_ap.json "$AUTH_PROFILES"
}

case "$1" in
  start)
    echo "Starting Vertex AI proxy..."
    pkill -f "bifrost/run.sh" 2>/dev/null
    pkill -f "bifrost/proxy.js" 2>/dev/null
    sleep 1
    nohup "$PROXY_DIR/run.sh" >> "$PROXY_DIR/proxy.log" 2>&1 &
    sleep 3
    if curl -s http://localhost:4100/ | grep -q vertex; then
      enable_proxy
      echo "✓ Proxy running on port 4100"
      echo "✓ OpenClaw pointed to Vertex AI"
      echo "  Restart gateway to apply"
    else
      echo "✗ Proxy failed to start. Check $PROXY_DIR/proxy.log"
    fi
    ;;
  stop)
    echo "Stopping Vertex AI proxy..."
    pkill -f "bifrost/run.sh" 2>/dev/null
    pkill -f "bifrost/proxy.js" 2>/dev/null
    disable_proxy
    echo "✓ Proxy stopped"
    echo "✓ OpenClaw reverted to default provider"
    echo "  Restart gateway to apply"
    ;;
  status)
    if curl -s -m 2 http://localhost:4100/ | grep -q vertex; then
      echo "✓ Proxy: RUNNING (port 4100)"
    else
      echo "✗ Proxy: DOWN"
    fi
    CURRENT_MODEL=$(jq -r '.session.defaultModel // "unknown"' "$OC_CONF" 2>/dev/null)
    SESSION_MODEL=$(grep -oP '"model"\s*:\s*"\K[^"]+' "$SESSIONS" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    CURRENT_URL=$(jq -r '.models.providers.anthropic.baseUrl' "$OC_CONF" 2>/dev/null)
    echo "  Model: ${SESSION_MODEL:-unknown}"
    echo "  Route: ${CURRENT_URL}"
    ;;
  model)
    if [ -z "$2" ]; then
      echo "Available models:"
      echo "  claude-sonnet-4-6"
      echo "  claude-opus-4-6"
      echo "  claude-haiku-4-5"
      echo ""
      SESSION_MODEL=$(grep -oP '"model"\s*:\s*"\K[^"]+' "$SESSIONS" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
      echo "Current: ${SESSION_MODEL:-unknown}"
      echo ""
      echo "Usage: vertex-ctl model <model-name>"
      exit 0
    fi
    NEW_MODEL="$2"
    # Get current model from sessions
    OLD_MODEL=$(grep -oP '"model"\s*:\s*"\K[^"]+' "$SESSIONS" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    if [ -z "$OLD_MODEL" ]; then
      echo "✗ Could not detect current model in sessions"
      exit 1
    fi
    # Update sessions
    sed -i "s|${OLD_MODEL}|${NEW_MODEL}|g" "$SESSIONS"
    COUNT=$(grep -c "$NEW_MODEL" "$SESSIONS")
    # Update openclaw default — use anthropic/ provider (proxy handles vertex translation)
    openclaw models set "anthropic/${NEW_MODEL}" 2>&1 | tail -1
    echo "✓ Model switched: ${OLD_MODEL} → ${NEW_MODEL} (${COUNT} refs)"
    echo "  Restart gateway to apply"
    ;;
  *)
    echo "Vertex AI Proxy Controller"
    echo ""
    echo "Usage: vertex-ctl {start|stop|status|model}"
    echo ""
    echo "  start          Start proxy, point OpenClaw to Vertex AI"
    echo "  stop           Stop proxy, revert to default provider"
    echo "  status         Show proxy status and current model"
    echo "  model          Show current model"
    echo "  model <name>   Switch model (e.g. claude-opus-4-6)"
    exit 1
    ;;
esac
