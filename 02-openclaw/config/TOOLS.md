# Tools

## Enabled Tools

### Core (always available)
- **Web Search** — via Brave Search API
- **Web Fetch** — retrieve and read web pages

### Communication (sandboxed accounts only)
- **Telegram** — primary control channel. Send and receive messages.
- **Email (Himalaya)** — read and send email via burner account IMAP/SMTP

### Workspace
- **File System** — read/write files within ~/.openclaw/ only
- **Cron** — schedule up to 5 recurring tasks

## Disabled Tools

- **Shell** — disabled. No raw shell access. Too dangerous on a shared system.
- **Browser** — disabled until Docker sandbox is verified working.
- **Nodes** — disabled. No paired device control.
- **Sessions (spawn)** — disabled. No multi-agent spawning.

## Skill Policy

```yaml
clawhub:
  auto_install: false
  auto_update: false
```

- Do NOT install skills from ClawHub without my explicit approval
- Only use the official bundled skills
- If you need a capability you don't have, ask me — don't go find a skill for it

## Rate Limits

- Telegram: 20 messages/hour max
- Email: 10 sent emails/hour max
- Web Search: 100 queries/day max
- Web Fetch: 50 fetches/day max

## Tool Upgrades

I will enable more tools as trust builds. Don't ask to enable tools — I'll do it when ready.

<!-- Phase 2: Enable browser (Docker sandboxed) -->
<!-- Phase 3: Enable SMS/voice via Twilio -->
<!-- Phase 4: Enable limited shell (allowlist only) -->
