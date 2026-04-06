# Contributing to vertex-proxy

Thanks for your interest in contributing! Here's how to get started.

## Development Setup

```bash
git clone https://github.com/netanel-abergel/vertex-proxy.git
cd vertex-proxy
npm install
```

## Running Locally

```bash
# Set your GCP project
export VERTEX_PROJECT_ID=your-project
gcloud auth application-default login

# Start the proxy
node src/proxy.js

# Test it
curl http://localhost:4100/health
```

## Making Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes
4. Test locally
5. Commit with a clear message
6. Open a pull request

## Guidelines

- Keep it simple — the proxy is intentionally minimal (~140 lines)
- One dependency is a feature, not a limitation
- Test with both streaming and non-streaming requests
- Environment variables for configuration, not config files

## Reporting Issues

Open an issue with:
- What you expected to happen
- What actually happened
- Your Node.js version and OS
- Relevant logs (with sensitive data redacted)
