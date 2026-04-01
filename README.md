# Vertex AI Proxy for OpenClaw

Translates Anthropic API requests to Google Cloud Vertex AI, allowing OpenClaw to use Claude models via your GCP project. The proxy passes through the model name from each request — no hardcoded model.

## Architecture

```
OpenClaw (anthropic provider, baseUrl → localhost:4100)
  → http://localhost:4100 (Node.js proxy)
    → @anthropic-ai/vertex-sdk
      → Vertex AI (devex-ai project, us-east5)
        → Claude model from request (e.g. claude-sonnet-4-6)
```

**Key concept:** OpenClaw uses the `anthropic` provider with `baseUrl` pointed to the local proxy. The proxy translates the standard Anthropic API format to Vertex AI. The model name is taken from the request, not hardcoded.

## Setup

```bash
# On the Ocana machine (Linux or macOS):
mkdir -p /opt/ocana/bifrost
cp proxy.js run.sh /opt/ocana/bifrost/
cp vertex-ctl.sh /usr/local/bin/vertex-ctl
chmod +x /opt/ocana/bifrost/run.sh /usr/local/bin/vertex-ctl
cd /opt/ocana/bifrost && npm init -y && npm install @anthropic-ai/vertex-sdk

# Copy GCP ADC credentials:
# Place your application_default_credentials.json at /opt/ocana/openclaw/gcp-adc.json
```

## Commands

| Command | What it does |
|---------|-------------|
| `vertex-ctl start` | Starts proxy, points OpenClaw anthropic provider to `localhost:4100` |
| `vertex-ctl stop` | Stops proxy, reverts OpenClaw to `api.anthropic.com` |
| `vertex-ctl status` | Shows proxy status, current model, and routing |
| `vertex-ctl model` | Shows current model and available options |
| `vertex-ctl model <name>` | Switch model (e.g. `claude-sonnet-4-6`, `claude-opus-4-6`) |

After `start`, `stop`, or `model`, restart the gateway:
```bash
openclaw gateway restart
```

## How it works

1. `vertex-ctl start` does three things:
   - Starts the proxy on port 4100 (via `run.sh`)
   - Updates OpenClaw's `anthropic` provider `baseUrl` to `http://localhost:4100`
   - Sets `apiKey` to `vertex-proxy` (dummy value, proxy uses GCP ADC)

2. OpenClaw sends requests to `http://localhost:4100/v1/messages` using the `anthropic` provider
3. The proxy forwards them to Vertex AI using the `@anthropic-ai/vertex-sdk`
4. The model name is passed through from the request (e.g. `claude-sonnet-4-6`)

## Files

- `proxy.js` - Node.js proxy server (pass-through, no hardcoded model)
- `run.sh` - Auto-restart wrapper (works on Linux and macOS)
- `vertex-ctl.sh` - Management CLI (installed to `/usr/local/bin/vertex-ctl`)

## Troubleshooting

**"Unknown model: anthropic-vertex/..."**
The model prefix should be `anthropic/`, not `anthropic-vertex/`. The proxy handles the Vertex translation. Run:
```bash
openclaw models set "anthropic/claude-sonnet-4-6"
openclaw gateway restart
```

**Proxy fails to start on macOS**
The `run.sh` script auto-detects the OS. If `fuser` is unavailable, it falls back to `lsof`. If `nohup` fails with permission errors, ensure `/opt/ocana/bifrost/` is owned by the current user:
```bash
sudo chown -R $(whoami) /opt/ocana/bifrost
```

**Config validation errors after enable_proxy**
If `openclaw gateway restart` shows "models: expected array, received undefined", the `jq` update may have wiped the models array. Run `openclaw doctor --fix` and then `vertex-ctl start` again.

**GCP ADC tokens expire**
ADC refresh tokens expire in ~1 hour. For production, use a GCP service account key instead.

## Notes

- Proxy auto-restarts on crash (3s delay)
- Add a crontab `@reboot` entry to auto-start on machine reboot:
  ```
  @reboot /opt/ocana/bifrost/run.sh >> /opt/ocana/bifrost/proxy.log 2>&1
  ```
