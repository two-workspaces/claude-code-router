# Deploy and Host Claude Code Router on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/claude-code-router?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=claude-code-router)

[Claude Code Router](https://github.com/musistudio/claude-code-router) (CCR) is an open-source model gateway for coding agents. Point Claude Code, Codex, OpenCode or any OpenAI- or Anthropic-compatible client at it, and it sends each request to the provider and model you choose: OpenRouter, DeepSeek, Gemini, OpenAI, Anthropic or your own endpoint. This template runs it as one always-on service with a browser management UI, so every machine and teammate shares the same routing, keys and logs.

## About Hosting Claude Code Router

One service, one volume. The image is built from Claude Code Router's own Docker setup: Nginx serves the management UI and the gateway on a single port, and the CCR server runs behind it. Providers, routing rules, client API keys, usage and request logs live in SQLite files on a volume at `/data`, so they survive redeploys. The management UI is protected by a generated token, and gateway requests need a client key you create in the UI. Your provider credentials stay on your own Railway service.

## Common Use Cases

- Run Claude Code against other models (DeepSeek, Gemini, Kimi, GLM, OpenRouter) without changing the tool
- Give a team one gateway URL with separate client keys instead of sharing provider keys
- Route by rule: a cheap model for background tasks, a strong one for reasoning, with fallbacks when a provider fails
- See every agent's requests, tokens, latency and errors in one log

## Dependencies for Claude Code Router Hosting

- An API key for at least one model provider. Nothing else: single service, no database.

### Deployment Dependencies

- [Claude Code Router](https://github.com/musistudio/claude-code-router) and [its documentation](https://ccrdesk.top/en/)
- [Docker deployment guide](https://ccrdesk.top/en/guides/docker/), which this template follows
- A provider account, for example [OpenRouter](https://openrouter.ai/) or [DeepSeek](https://platform.deepseek.com/)

### Implementation Details

**First use:**

1. Copy `CCR_WEB_AUTH_TOKEN` from the service's Variables tab and open `https://<your-domain>/?ccr_web_token=<token>`. Without the token the page loads but every action answers 401.
2. The setup wizard asks for a provider, its API key and the models to use, then tests the connection.
3. Its **Connect agent** step creates an agent profile inside the container. Accept the defaults and finish: the gateway starts, and it starts by itself on every boot from then on.
4. Open **API Keys** and create a client key for each machine or teammate.

**Connect a client.** The gateway is on the same domain as the UI. The UI shows the endpoint as `http://127.0.0.1:3456`, which is the address inside the container: from outside, use your Railway domain. Models are named `Provider/model`.

- Claude Code: `ANTHROPIC_BASE_URL=https://<your-domain>` and `ANTHROPIC_AUTH_TOKEN=<client key>`
- OpenAI-compatible tools: base URL `https://<your-domain>/v1` with the client key as the API key

**Variables:**

- `CCR_WEB_AUTH_TOKEN`: the management token, generated on deploy. Treat the URL that contains it as a secret. If you clear it, a new token is generated on every start and printed in the deploy log.
- `CCR_PUBLIC_BASE_URL`: the address CCR tells clients to use, and the only browser origin the management UI accepts. If you add a custom domain, set it to that domain.

Notes and limits:

- This is the server build of CCR. The desktop app's features are not in it: launching local agents, the system tray, desktop updates and browser login import.
- **Agent Profiles** write agent settings on the machine CCR runs on, which here is the container. For agents on your own machine, set the base URL and client key as above.
- `/health` reports the gateway, so it answers 502 until a provider is added and the gateway is running. The service's own healthcheck uses the UI page instead.
- 0.5 GB of RAM is enough: the service sits at about 370 MB with the gateway running.
- `/data` holds your provider credentials, client keys and request logs. Use **Settings → Export data** for backups and keep them private.
- New Claude Code Router versions arrive as template updates.

## Why Deploy Claude Code Router on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Claude Code Router on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
