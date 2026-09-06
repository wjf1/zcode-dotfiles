---
description: Show token usage, cache hit rate, latency, and call volume stats.
argument-hint: "[--days N | --today | --session <id> | --json]"
---

Run the ZCode usage statistics script and summarize the result for the user:

```
python "__ZCODE_HOME__\.zcode\scripts\usage_stats.py" $ARGUMENTS
```

Behavior:
- With no arguments, report the last 7 days.
- Present the summary block first (calls, input/output tokens, cache read hit rate, latency avg/median/p95), then the per-model table. The recent-calls table can be shortened to 5 rows unless the user asked for detail.
- If the user's arguments are a plain request like "today" or "this session", translate them: "today" → `--today`; "current/this session" → run `--json --days 7`, match the session id against the current session if known, else list top sessions by call count and ask which one.
- If the script prints "No model calls found", say so and suggest widening the window with `--days 30`.
