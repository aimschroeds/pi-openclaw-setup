# Heartbeat

Check these items every heartbeat cycle (default: every 30 minutes).
Only message me if something needs attention. If nothing needs action, respond HEARTBEAT_OK.

## Checks

### Email
- [ ] Check inbox for new emails. Summarize anything urgent via Telegram.
- [ ] Flag emails that need a reply (don't reply without my approval in Week 1-2).

### Calendar
- [ ] Check for upcoming events in the next 2 hours. Remind me via Telegram if I haven't been reminded yet.

### System Health
- [ ] Check Pi CPU temperature — alert me if over 80°C.
- [ ] Check disk usage — alert me if over 85% full.
- [ ] Verify the gateway is still bound to 127.0.0.1 (not 0.0.0.0).

## Rules

- Do NOT take action on any check — just report. I decide what to do.
- Keep messages short. One Telegram message per heartbeat, max.
- If nothing needs attention: respond HEARTBEAT_OK (the gateway drops this silently).
- Do not infer or repeat tasks from prior sessions. Only act on what's written above.

## Graduated Autonomy

As trust builds, I'll update this file to let you act on certain checks:
- Week 1-2: Report only. Never act.
- Week 3+: You may draft email replies (I approve before send).
- Week 4+: You may send pre-approved template responses.

<!-- Update this section as your comfort level increases. -->
