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

**Key concept:** OpenClaw uses the `anthropic` provider (NOT `anthropic-vertex`) with `baseUrl` pointed to the local proxy. The proxy translates the standard Anthropic API format to Vertex AI. The model name is taken from the request, not hardcoded.

## Prerequisites

1. **GCP ADC credentials** — generate with:
   ```bash
   gcloud auth application-default login --project devex-ai
   ```
   This creates `~/.config/gcloud/application_default_credentials.json`

2. **Node.js** installed on the Ocana machine

## Setup

```bash
# On the Ocana machine (Linux or macOS):
mkdir -p /opt/ocana/bifrost
cp proxy.js run.sh /opt/ocana/bifrost/
cp vertex-ctl.sh /usr/local/bin/vertex-ctl
chmod +x /opt/ocana/bifrost/run.sh /usr/local/bin/vertex-ctl
cd /opt/ocana/bifrost && npm init -y && npm install @anthropic-ai/vertex-sdk

# Copy GCP ADC credentials to the Ocana machine:
cp ~/.config/gcloud/application_default_credentials.json /opt/ocana/openclaw/gcp-adc.json
```

## Quick Start

```bash
vertex-ctl start              # Start proxy + configure OpenClaw
vertex-ctl test               # Verify it works end-to-end
openclaw gateway restart       # Apply changes
```

## Commands

| Command | What it does |
|---------|-------------|
| `vertex-ctl start` | Starts proxy, points OpenClaw anthropic provider to `localhost:4100` |
| `vertex-ctl stop` | Stops proxy, reverts OpenClaw to `api.anthropic.com` |
| `vertex-ctl status` | Shows proxy status, current model, and routing |
| `vertex-ctl test` | Sends a test message through the proxy to verify it works |
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

### `invalid_grant` error in proxy.log
The GCP refresh token has expired. Regenerate:
```bash
# On your local machine:
gcloud auth application-default login --project devex-ai

# Copy the new credentials to the Ocana machine:
# (copy ~/.config/gcloud/application_default_credentials.json to /opt/ocana/openclaw/gcp-adc.json)

# Then restart the proxy (kills old process, starts fresh with new creds):
vertex-ctl start
```
**Note:** ADC refresh tokens can expire. For production, use a GCP service account key instead.

### `Unknown model: anthropic-vertex/...`
The model prefix should be `anthropic/`, not `anthropic-vertex/`. The proxy handles the Vertex translation. Fix:
```bash
openclaw models set "anthropic/claude-sonnet-4-6"
openclaw gateway restart
```

### Proxy fails to start on macOS
The `run.sh` script auto-detects the OS. If `fuser` is unavailable, it falls back to `lsof`. If `nohup` fails with permission errors:
```bash
sudo chown -R $(whoami) /opt/ocana/bifrost
```

### Config validation errors (`models: expected array`)
The `jq` update wiped the models array. Fix:
```bash
openclaw doctor --fix
vertex-ctl start
openclaw gateway restart
```

### `vertex-ctl start` says "GCP credentials not found"
Copy your credentials file:
```bash
cp ~/.config/gcloud/application_default_credentials.json /opt/ocana/openclaw/gcp-adc.json
```

### How to verify the proxy works
```bash
vertex-ctl test
```
This sends a real request through the proxy to Vertex AI and shows the response.

## Notes

- Proxy auto-restarts on crash (3s delay via `run.sh`)
- `vertex-ctl start` kills any existing proxy before starting a new one
- Add a crontab `@reboot` entry to auto-start on machine reboot:
  ```
  @reboot /opt/ocana/bifrost/run.sh >> /opt/ocana/bifrost/proxy.log 2>&1
  ```
- The proxy logs to `/opt/ocana/bifrost/proxy.log`
