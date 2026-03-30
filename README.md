# Vertex AI Proxy for OpenClaw

Translates Anthropic API requests to Google Cloud Vertex AI, allowing OpenClaw to use Claude models via your GCP project.

## Architecture

```
OpenClaw (anthropic-messages API)
  -> http://localhost:4100 (Node.js proxy)
    -> @anthropic-ai/vertex-sdk
      -> Vertex AI (devex-ai project, us-east5)
        -> Claude Sonnet 4.6
```

## Setup

```bash
# On the Ocana machine:
mkdir -p /opt/ocana/bifrost
cp proxy.js run.sh /opt/ocana/bifrost/
cp vertex-ctl.sh /usr/local/bin/vertex-ctl
chmod +x /opt/ocana/bifrost/run.sh /usr/local/bin/vertex-ctl
cd /opt/ocana/bifrost && npm init -y && npm install @anthropic-ai/vertex-sdk

# Upload GCP ADC credentials:
# Copy your ~/.config/gcloud/application_default_credentials.json to /opt/ocana/openclaw/gcp-adc.json
```

## Commands

| Command | What it does |
|---------|-------------|
| `vertex-ctl start` | Starts proxy, points OpenClaw to Vertex AI |
| `vertex-ctl stop` | Stops proxy, reverts OpenClaw to default provider |
| `vertex-ctl status` | Shows proxy status and current routing |

After `start` or `stop`, restart the gateway from Ocana UI (Gateway Controls -> Restart Gateway).

## Files

- `proxy.js` - Node.js proxy server with crash protection
- `run.sh` - Auto-restart wrapper
- `vertex-ctl.sh` - Management CLI (installed to `/usr/local/bin/vertex-ctl`)

## Notes

- GCP ADC tokens expire in ~1 hour. For production, use a service account key.
- Proxy auto-restarts on crash (2s delay).
- Crontab `@reboot` entry ensures proxy starts on machine reboot.
