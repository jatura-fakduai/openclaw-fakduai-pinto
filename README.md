# OpenClaw + Pinto Docker

<img width="1672" alt="image" src="https://github.com/user-attachments/assets/61982e72-ea06-4b0e-8a99-20631efc8506" />


This project builds an OpenClaw Docker image with the Pinto channel plugin included.

It also includes common Linux libraries needed by Playwright/browser agents.

## What Is Included

- OpenClaw base image: `ghcr.io/openclaw/openclaw`
- Pinto plugin: `pinto-app-openclaw`
- Pinto channel id: `pinto`
- Web UI and webhook port: `18789`
- Config folder: `./openclaw-config`
- Auth folder: `./openclaw-auth`

## 1. Prepare `.env`

```bash
cd /Users/beer-fdlp/Workspace/Lab/OpenClaw-Pinto
cp .env.example .env
```

Edit `.env` and set a real login token:

```text
OPENCLAW_GATEWAY_TOKEN=your-long-random-token
```

You can generate one with:

```bash
openssl rand -hex 32
```

## 2. Build Image

```bash
docker compose build
```

## 3. Start Local OpenClaw

```bash
docker compose up -d
```

Open:

```text
http://127.0.0.1:18789/
```

Login with:

```bash
grep '^OPENCLAW_GATEWAY_TOKEN=' .env
```

## 4. Use Cloudflare Quick Tunnel

Quick Tunnel is useful for testing only. The URL changes when cloudflared restarts.

Start:

```bash
docker compose -f docker-compose.yml -f docker-compose.trycloudflare.yml up -d
```

View the generated URL:

```bash
docker compose -f docker-compose.yml -f docker-compose.trycloudflare.yml logs -f cloudflared
```

Example:

```text
https://something-random.trycloudflare.com
```

Allow this browser origin in OpenClaw:

```bash
printf '%s\n' '{"gateway":{"controlUi":{"allowedOrigins":["http://localhost:18789","http://127.0.0.1:18789","https://something-random.trycloudflare.com"]}}}' | docker compose run --rm -T openclaw-cli config patch --stdin --replace-path gateway.controlUi.allowedOrigins
docker compose restart openclaw-gateway
```

Use:

```text
Web UI:  https://something-random.trycloudflare.com/
Webhook: https://something-random.trycloudflare.com/plugins/pinto/webhook
```

Do not run `down` for Quick Tunnel unless you are okay with getting a new URL.

Config model

```bash
docker compose run --rm openclaw-cli configure --section model
```

## 5. Use Cloudflare With Your Domain

This is the recommended long-term setup.

In Cloudflare Zero Trust:

1. Go to **Networks > Tunnels**.
2. Create a tunnel.
3. Choose **Cloudflared**.
4. Choose **Docker**.
5. Copy the token after `--token`.
6. Add a Public Hostname, for example `openclaw.example.com`.
7. Set service type to `HTTP`.
8. Set service URL to:

```text
openclaw-gateway:18789
```

Edit `.env`:

```text
CLOUDFLARE_TUNNEL_TOKEN=eyJ...
PUBLIC_OPENCLAW_URL=https://openclaw.example.com
PINTO_WEBHOOK_URL=https://openclaw.example.com/plugins/pinto/webhook
```

Start:

```bash
docker compose -f docker-compose.yml -f docker-compose.cloudflare.yml up -d
```

Use:

```text
Web UI:  https://openclaw.example.com/
Webhook: https://openclaw.example.com/plugins/pinto/webhook
```

## 6. Approve Browser Device

If the UI says `Device pairing required`, run:

```bash
docker compose run --rm openclaw-cli devices list
docker compose run --rm openclaw-cli devices approve DEVICE_ID
```

Example:

```bash
docker compose run --rm openclaw-cli devices approve a57e05c8-8a01-413a-b172-702a3261dcfc
```

Then reload the browser.

## 7. Configure Pinto

Open the Web UI:

```text
Channels > Pinto Chat
```

Minimum settings:

- `Enabled`: `true`
- `Api Url`: `https://api.pinto-app.com`
- `Bot Id`: your real Pinto bot UUID
- `Webhook Secret`: your shared secret
- `Webhook Path`: `/plugins/pinto/webhook`

Or configure with CLI:

```bash
printf '%s\n' '{"channels":{"pinto":{"enabled":true,"apiUrl":"https://api.pinto-app.com","botId":"YOUR_PINTO_BOT_UUID","webhookSecret":"YOUR_WEBHOOK_SECRET","webhookPath":"/plugins/pinto/webhook"}}}' | docker compose run --rm -T openclaw-cli config patch --stdin
docker compose restart openclaw-gateway
```

Test webhook:

```bash
curl -i https://your-domain.example/plugins/pinto/webhook
```

Expected:

```json
{"ok":true,"channel":"pinto"}
```

## Common Commands

Show running containers:

```bash
docker compose ps
```

View gateway logs:

```bash
docker compose logs -f openclaw-gateway
```

View Cloudflare logs:

```bash
docker compose -f docker-compose.yml -f docker-compose.trycloudflare.yml logs -f cloudflared
```

Run OpenClaw CLI:

```bash
docker compose run --rm openclaw-cli plugins list
docker compose run --rm openclaw-cli channels list
docker compose run --rm openclaw-cli config validate
```

Open shell inside CLI container:

```bash
docker compose run --rm --entrypoint sh openclaw-cli
```

Restart OpenClaw only:

```bash
docker compose restart openclaw-gateway
```

Stop local stack:

```bash
docker compose down
```

More agent communication notes:

```text
docs/agent-communication.md
```

## Reset

Reset login token:

1. Edit `.env`.
2. Change `OPENCLAW_GATEWAY_TOKEN`.
3. Rebuild and restart:

```bash
docker compose build
docker compose up -d
```

Reset all OpenClaw config and auth:

```bash
docker compose down
rm -rf openclaw-config openclaw-auth
docker compose up -d
```

Full clean rebuild:

```bash
docker compose down
rm -rf openclaw-config openclaw-auth
docker compose build --no-cache
docker compose up -d
```

## Troubleshooting

### `Browser origin not allowed`

Add the public origin to `gateway.controlUi.allowedOrigins`.

Use only the origin:

```text
https://something-random.trycloudflare.com
```

Do not use the webhook path:

```text
https://something-random.trycloudflare.com/plugins/pinto/webhook
```

### `Auth did not match`

The browser token and gateway token do not match.

Fix:

1. Check `.env`.
2. Copy `OPENCLAW_GATEWAY_TOKEN`.
3. Open a private browser window.
4. Paste the token again.

### `Unable to reach the origin service`

Cloudflare is running, but OpenClaw is not listening on `18789`.

Check:

```bash
docker compose ps
docker compose logs --tail=100 openclaw-gateway
```

Usually fix:

```bash
docker compose restart openclaw-gateway
```

### Pinto webhook returns `not found`

The Pinto channel is not fully configured yet.

Set a real `Bot Id`, then restart:

```bash
docker compose restart openclaw-gateway
```

### Quick Tunnel URL changed

This is normal. Quick Tunnel URLs are temporary.

Update:

- `gateway.controlUi.allowedOrigins`
- Pinto webhook URL

For stable training, use a named Cloudflare Tunnel with your own domain.
