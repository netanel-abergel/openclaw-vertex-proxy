<p align="center">
  <img src="https://img.shields.io/badge/Vertex_AI-Anthropic_Proxy-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white" alt="Vertex AI Anthropic Proxy" />
</p>

<h1 align="center">vertex-proxy</h1>

<p align="center">
  Route any Anthropic-compatible client through Google Cloud Vertex AI.<br/>
  Drop-in proxy — zero client changes, just point <code>baseUrl</code> to localhost.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="MIT License" /></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/node-%E2%89%A518-green?style=flat-square" alt="Node.js 18+" /></a>
  <a href="https://cloud.google.com/vertex-ai"><img src="https://img.shields.io/badge/GCP-Vertex%20AI-4285F4?style=flat-square" alt="Vertex AI" /></a>
  <a href="Dockerfile"><img src="https://img.shields.io/badge/docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Docker" /></a>
</p>

---

## Why?

Many tools speak the [Anthropic Messages API](https://docs.anthropic.com/en/api/messages) — Claude Code, Cursor, Continue, Cline, aider, and more. But if your organization routes AI through **Google Cloud Vertex AI** (for billing, compliance, or data residency), you need a translation layer.

**vertex-proxy** sits between your client and Vertex AI:

```
┌─────────────────────────┐
│  Any Anthropic Client   │  (Claude Code, Cursor, etc.)
│  baseUrl → localhost     │
└──────────┬──────────────┘
           │  Standard Anthropic API
           ▼
┌─────────────────────────┐
│    vertex-proxy :4100   │  Node.js  ·  ~140 lines
└──────────┬──────────────┘
           │  @anthropic-ai/vertex-sdk
           ▼
┌─────────────────────────┐
│  Vertex AI (primary)    │──failover──▶ Vertex AI (fallback)
│  e.g. us-east5          │             e.g. us-central1
└─────────────────────────┘
```

**No code changes in your client.** Same model names, same API format — just swap `baseUrl`.

## Quick Start

```bash
# 1. Clone & install
git clone https://github.com/netanel-abergel/vertex-proxy.git
cd vertex-proxy
npm install

# 2. Authenticate with GCP
gcloud auth application-default login

# 3. Start the proxy
VERTEX_PROJECT_ID=my-project node src/proxy.js
```

Then point your client's `baseUrl` to `http://localhost:4100` and set any dummy API key.

### Docker

```bash
docker build -t vertex-proxy .
docker run -p 4100:4100 \
  -e VERTEX_PROJECT_ID=my-project \
  -v ~/.config/gcloud/application_default_credentials.json:/app/creds.json:ro \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/creds.json \
  vertex-proxy
```

## Client Examples

<details>
<summary><b>Claude Code</b></summary>

```bash
# Set the base URL and a dummy API key
export ANTHROPIC_BASE_URL=http://localhost:4100
export ANTHROPIC_API_KEY=vertex-proxy

claude
```
</details>

<details>
<summary><b>Cursor</b></summary>

In Cursor settings → Models → Anthropic:
- **Base URL:** `http://localhost:4100`
- **API Key:** `vertex-proxy` (any non-empty value)
</details>

<details>
<summary><b>curl</b></summary>

```bash
curl -X POST http://localhost:4100/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```
</details>

## Configuration

All settings via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VERTEX_PROJECT_ID` | `devex-ai` | GCP project ID |
| `VERTEX_REGION` | `us-east5` | Primary Vertex AI region |
| `VERTEX_FALLBACK_REGION` | `us-central1` | Fallback region (on 5xx errors) |
| `PROXY_PORT` | `4100` | Proxy listening port |
| `VERTEX_MAX_CONCURRENT` | `20` | Max concurrent requests (429 when exceeded) |
| `VERTEX_DEBUG` | `0` | Set to `1` for verbose logging |
| `GOOGLE_APPLICATION_CREDENTIALS` | GCP default | Path to service account or ADC credentials |

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/messages` | POST | Proxied Anthropic Messages API |
| `/health` | GET | Health check (project, region, active requests, uptime) |
| `/` | GET | Basic liveness check |

## Features

- **Region failover** — automatic retry on fallback region when primary returns 5xx
- **Concurrency limiting** — returns `429` when max concurrent requests exceeded
- **Streaming support** — full SSE streaming pass-through
- **Request validation** — rejects malformed requests with descriptive 400 errors
- **Graceful shutdown** — drains in-flight requests on SIGTERM/SIGINT
- **Model pass-through** — uses whatever model the client requests, no hardcoding
- **Tiny footprint** — single file, one dependency, ~140 lines

## Production Deployment

For production use, the repo includes helper scripts:

| File | Purpose |
|------|---------|
| `src/proxy.js` | The proxy server |
| `scripts/run.sh` | Auto-restart wrapper with crash guard (5 crashes/60s limit) and log rotation |
| `scripts/vertex-ctl.sh` | Management CLI (`start`, `stop`, `status`, `test`, `model`) |
| `Dockerfile` | Container deployment with health checks |

### `run.sh` — Process Supervisor

Wraps `proxy.js` with auto-restart, crash detection, and log rotation:

```bash
./scripts/run.sh  # auto-restarts on crash, rotates logs at 10MB
```

### `vertex-ctl.sh` — Management CLI

> **Note:** `vertex-ctl.sh` was built for a specific deployment setup. You'll likely want to adapt the paths in the script to match your environment.

```bash
vertex-ctl start    # Start proxy
vertex-ctl stop     # Stop proxy
vertex-ctl status   # Show proxy status
vertex-ctl test     # Send a test request
```

## Troubleshooting

<details>
<summary><code>invalid_grant</code> error</summary>

Your GCP credentials have expired. Regenerate:

```bash
gcloud auth application-default login
```

For production, use a **service account key** instead of ADC user credentials.
</details>

<details>
<summary>Proxy crashes in a loop</summary>

`run.sh` stops automatically after 5 crashes within 60 seconds. Check `proxy.log` for the root cause before restarting.
</details>

<details>
<summary>Port already in use</summary>

```bash
# Find and kill the process on port 4100
lsof -ti :4100 | xargs kill
```
</details>

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — Netanel Abergel
