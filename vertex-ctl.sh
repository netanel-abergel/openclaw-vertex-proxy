#!/bin/bash
# Vertex AI Proxy Controller for OpenClaw
# Usage: vertex-ctl {start|stop|status}

PROXY_DIR="/opt/ocana/bifrost"
OC_CONF="/opt/ocana/openclaw/openclaw.json"
AGENT_MODELS="/opt/ocana/openclaw/agents/main/agent/models.json"
AUTH_PROFILES="/opt/ocana/openclaw/agents/main/agent/auth-profiles.json"
GCP_CREDS="/opt/ocana/openclaw/gcp-adc.json"

enable_proxy() {
  # Point anthropic provider to local proxy
  jq '.models.providers.anthropic.baseUrl = "http://localhost:4100" | .models.providers.anthropic.apiKey = "vertex-proxy"' "$OC_CONF" > /tmp/_oc.json && cp /tmp/_oc.json "$OC_CONF"
  jq '.providers.anthropic.baseUrl = "http://localhost:4100" | .providers.anthropic.apiKey = "vertex-proxy"' "$AGENT_MODELS" > /tmp/_am.json && cp /tmp/_am.json "$AGENT_MODELS"
  jq '.["anthropic:manual"] = {"provider":"anthropic","token":"vertex-proxy","profileId":"anthropic:manual"}' "$AUTH_PROFILES" > /tmp/_ap.json && cp /tmp/_ap.json "$AUTH_PROFILES"
}

disable_proxy() {
  # Revert anthropic provider to direct API (or OpenAI fallback)
  jq '.models.providers.anthropic.baseUrl = "https://api.anthropic.com" | .models.providers.anthropic.apiKey = ""' "$OC_CONF" > /tmp/_oc.json && cp /tmp/_oc.json "$OC_CONF"
  jq '.providers.anthropic.baseUrl = "https://api.anthropic.com" | .providers.anthropic.apiKey = ""' "$AGENT_MODELS" > /tmp/_am.json && cp /tmp/_am.json "$AGENT_MODELS"
  jq 'del(.["anthropic:manual"])' "$AUTH_PROFILES" > /tmp/_ap.json && cp /tmp/_ap.json "$AUTH_PROFILES"
}

case "$1" in
  start)
    echo "Starting Vertex AI proxy..."
    # Kill existing
    pkill -f "bifrost/run.sh" 2>/dev/null
    pkill -f "bifrost/proxy.js" 2>/dev/null
    sleep 1
    # Start with auto-restart wrapper
    nohup "$PROXY_DIR/run.sh" >> "$PROXY_DIR/proxy.log" 2>&1 &
    sleep 3
    if curl -s http://localhost:4100/ | grep -q vertex; then
      enable_proxy
      echo "✓ Proxy running on port 4100"
      echo "✓ OpenClaw pointed to Vertex AI (claude-sonnet-4-6)"
      echo "  Restart gateway to apply: use Ocana UI or 'openclaw gateway restart'"
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
    echo "✓ OpenClaw reverted to default (direct Anthropic API)"
    echo "  Restart gateway to apply: use Ocana UI or 'openclaw gateway restart'"
    ;;
  status)
    if curl -s -m 2 http://localhost:4100/ | grep -q vertex; then
      echo "✓ Proxy: RUNNING (port 4100)"
      echo "  Route: OpenClaw → localhost:4100 → Vertex AI → Claude Sonnet 4.6"
    else
      echo "✗ Proxy: DOWN"
      echo "  Route: OpenClaw → default provider"
    fi
    CURRENT=$(jq -r '.models.providers.anthropic.baseUrl' "$OC_CONF" 2>/dev/null)
    echo "  anthropic baseUrl: $CURRENT"
    ;;
  *)
    echo "Usage: vertex-ctl {start|stop|status}"
    exit 1
    ;;
esac
