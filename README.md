# Life Organizer

A self-hosted task list and calendar that Claude can connect to. It's the first piece of a
bigger life organizer, so it's built from modules that are easy to add to.

- **Tasks:** notes, due dates and times, priorities, tags, projects, subtasks and repeats.
- **Calendar:** events, all-day events, repeats (with "just this one" edits), reminders,
  day, week, month and list views, and your tasks shown on it.
- **Time blocking:** drag a task onto the calendar to reserve time for it. Drag or stretch
  the block to move it. Ask Claude to "find two free hours for the report" and it can do the same.
- **Works on a phone:** a responsive web app with a bottom tab bar, light and dark themes, and
  "Add to Home Screen" support.
- **Claude connector:** an MCP server at `/mcp`, with OAuth sign-in for claude.ai and API keys for
  Claude Code and scripts.
- **REST API** with API keys, and a private **calendar feed** (ICS) for your phone's calendar app.

Built with Ruby on Rails 8, Hotwire (Turbo and Stimulus), SQLite and FullCalendar.
One container, one database file.

## Run it with Docker (recommended)

You need Docker with the Compose plugin on the machine that will host it.

```sh
git clone https://github.com/kgoke/life-organizer.git
cd life-organizer
cp .env.example .env
# Edit .env: set ADMIN_PASSWORD, PUBLIC_URL and APP_TIMEZONE at least.
docker compose up -d --build
```

The app now answers on `http://127.0.0.1:3000` on that machine. Sign in with `ADMIN_PASSWORD`.
The database lives in the `organizer-data` Docker volume, so rebuilding or updating the
container keeps your data.

To update later: `git pull && docker compose up -d --build`.

### Settings (`.env`)

| Variable | What it does |
| --- | --- |
| `ADMIN_PASSWORD` | Your password for the web app, and for approving Claude's connection. **Required.** |
| `PUBLIC_URL` | The https address the app is reached at, for example `https://organizer.example.com`. Claude uses it to find the sign-in pages. |
| `APP_TIMEZONE` | Your time zone, such as `America/New_York` or `Europe/London`. Times without a zone are read in it. |
| `DAY_START`, `DAY_END` | Working hours for free-time search and the calendar's shading. Default 08:00 to 18:00. |
| `ASSUME_SSL` | `true` when a tunnel or proxy in front of the app handles HTTPS. |
| `FORCE_SSL` | `true` to redirect plain http to https. Leave `false` behind a tunnel. |
| `OAUTH_ENABLED` | `true` lets claude.ai connect with OAuth. API keys work either way. |
| `SECRET_KEY_BASE` | Optional. If blank, one is generated and kept in the data volume. |
| `HOST_PORT` | The port on the host machine. Default 3000. |

## Put it on the internet safely (HTTPS)

claude.ai connects to your app from Anthropic's servers, so the app needs a public **https**
address. Don't open the port on your router. Use one of these instead.

### Option A: Cloudflare Tunnel (needs a domain on Cloudflare)

1. In the Cloudflare dashboard, open **Zero Trust → Networks → Tunnels** and create a tunnel.
   Copy its token.
2. Add a public hostname, such as `organizer.example.com`, that points to the service
   `http://app:80`.
3. In `.env`, set `CLOUDFLARE_TUNNEL_TOKEN` to the token, `PUBLIC_URL=https://organizer.example.com`
   and `ASSUME_SSL=true`.
4. Run `docker compose --profile tunnel up -d`.

### Option B: Tailscale Funnel (no domain needed)

1. Install Tailscale on the host and sign in. Enable HTTPS and Funnel for your tailnet in the
   Tailscale admin console.
2. Run `sudo tailscale funnel --bg 3000`. Tailscale prints an address like
   `https://myserver.tailnet-name.ts.net`.
3. Set `PUBLIC_URL` to that address and `ASSUME_SSL=true` in `.env`, then
   `docker compose up -d`.

If you only want to use it at home and with Claude Code on the same network, you can skip this
and change the port line in `docker-compose.yml` to `"3000:80"`. claude.ai's connector won't be
able to reach it then.

### Security notes

- Everything except the sign-in pages, `/up` and the calendar feed needs your password, an API
  key or an OAuth token. Sign-in attempts are rate limited.
- API keys and OAuth tokens are stored only as SHA-256 digests. Revoke them in **Settings**.
- The calendar feed address contains a long secret. Treat it like a password, and make a new one
  in Settings if it leaks.
- Use a long `ADMIN_PASSWORD`. It's the one key to everything.

## Connect Claude

Open **Settings** in the app. It shows the exact addresses for your server.

### claude.ai (web, desktop and mobile apps)

1. In Claude, open **Settings → Connectors → Add custom connector**.
2. Name it "Life Organizer" and paste your connector address: `PUBLIC_URL/mcp`, for example
   `https://organizer.example.com/mcp`.
3. Claude opens your organizer's approval page. Enter your password and choose **Allow**.

Then ask things like "What's on my plate today?", "Add a task to renew my passport next
Friday", or "Block an hour tomorrow afternoon for the budget".

You can disconnect Claude any time under **Settings → Connected apps**.

### Claude Code

Make an API key in **Settings → API keys**, then run:

```sh
claude mcp add --transport http life-organizer https://organizer.example.com/mcp \
  --header "Authorization: Bearer lo_your_key_here"
```

Claude Code on the same network can use `http://SERVER_IP:3000/mcp` instead.

The tools Claude gets are listed in [docs/API.md](docs/API.md#mcp-tools).

## Calendar feed

**Settings → Calendar feed** gives you an `.ics` address. Subscribe to it in Apple Calendar,
Google Calendar or Outlook to see your events, time blocks and due tasks there. It's read-only,
and most calendar apps refresh subscriptions every few hours.

## Backups

The whole organizer is one SQLite file. To make a safe copy while it runs:

```sh
docker compose exec app bin/backup
```

That writes `storage/backups/organizer-YYYYMMDD-HHMMSS.sqlite3` inside the data volume and keeps
the newest 30. To copy backups off the server:

```sh
docker compose cp app:/rails/storage/backups ./organizer-backups
```

For a daily backup, add a cron job on the host, for example:

```
0 3 * * * cd /path/to/life-organizer && docker compose exec -T app bin/backup
```

To restore, stop the app (`docker compose stop app`), copy a backup over
`/rails/storage/production.sqlite3` in the volume, delete any `production.sqlite3-wal` and
`production.sqlite3-shm` files beside it, and start the app again.

## Develop

You need Ruby 3.3 and SQLite.

```sh
bundle install
bin/rails db:prepare
ADMIN_PASSWORD=dev bin/rails server
```

Open http://localhost:3000. Run the tests with `bin/rails test`, and the security checks with
`bin/brakeman` and `bin/bundler-audit`.

Where things live:

- `app/models`: tasks, projects, calendars, events, API keys and OAuth records.
- `app/services`: the logic, shared by the web pages, the REST API and the MCP server
  (`TaskWriter`, `EventWriter`, `CalendarQuery`, `Agenda`, `IcsFeed`, `OauthFlow`, `Mcp::Server`).
- `app/organizer_modules`: each feature area as a module that adds MCP tools and a tab in the app.
  See [docs/MODULES.md](docs/MODULES.md) to add a new one.
- `app/javascript/controllers`: Stimulus controllers, including the drag-and-drop calendar.

## License

Private project. FullCalendar (vendored in `vendor/javascript`) is MIT licensed.
