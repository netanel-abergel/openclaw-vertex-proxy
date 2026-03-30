process.on('uncaughtException', (err) => { console.error('UNCAUGHT:', err.message); });
process.on('unhandledRejection', (err) => { console.error('UNHANDLED:', err.message || err); });

const http = require('http');
const { AnthropicVertex } = require('@anthropic-ai/vertex-sdk');
const PROJECT_ID = 'devex-ai';
const REGION = 'us-east5';
const PORT = 4100;
const client = new AnthropicVertex({ projectId: PROJECT_ID, region: REGION });

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'POST' && req.url.includes('/v1/messages')) {
      let body = '';
      for await (const chunk of req) body += chunk;
      const params = JSON.parse(body);
      console.log('Proxy:', params.model, params.stream ? 'stream' : 'sync');
      try {
        if (params.stream) {
          res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive' });
          const stream = client.messages.stream(params);
          for await (const event of stream) {
            res.write('event: ' + event.type + '\ndata: ' + JSON.stringify(event) + '\n\n');
          }
          res.write('event: message_stop\ndata: {}\n\n');
          res.end();
        } else {
          const response = await client.messages.create(params);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(response));
        }
      } catch (err) {
        console.error('API error:', err.message, err.status);
        res.writeHead(err.status || 502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ type: 'error', error: { type: 'api_error', message: err.message } }));
      }
    } else {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', proxy: 'vertex-ai-proxy' }));
    }
  } catch (err) {
    console.error('Server error:', err.message);
    try { res.writeHead(500); res.end('Internal error'); } catch(e) {}
  }
});
server.listen(PORT, () => console.log('Vertex AI proxy on port ' + PORT));
