---
description: Show a scorecard of how often each ast-grep rule has fired in this project, with timing
---

You are showing a scorecard for ast-checker rule fires in the current project. Read the log and present aggregate stats.

## Step 1: Find the log

1. Find project root: `git rev-parse --show-toplevel` (fall back to cwd).
2. Log path: `<project-root>/.ast-grep/log.jsonl`.
3. If the file doesn't exist or is empty, tell the user "No fires logged yet — the hook hasn't blocked anything in this project. Either rules are silent (good) or you've never edited a file that matched (less informative)." Then stop.

## Step 2: Parse and aggregate

Each line of the log is JSON:
```json
{"ts": "2026-04-25T10:00:00Z", "rules": ["rule-id-1"], "file": "path/to/file", "scan_ms": 87}
```

Per rule, compute:
- **Fires**: count of log entries containing this rule
- **Last fired**: most recent `ts` for this rule (relative — "2 days ago", "1 week ago", etc.)
- **Avg scan ms**: average `scan_ms` across all entries containing this rule
- **Top files**: top 3 files that fired this rule, with counts

Also compute:
- **Total fires** across all rules
- **Date range** of log entries (first to last)

## Step 3: Present as a table

```
Rule scorecard for <project-root>
Log range: <first ts> to <last ts> (<N total fires>)

| Rule | Fires | Last fired | Avg scan (ms) | Top files |
|---|---|---|---|---|
| rule-name-1 | 12 | 2 days ago | 64 | runner.py (8), routes.py (4) |
| rule-name-2 | 3 | 1 week ago | 71 | runner.py (3) |
```

Sort by fire count descending.

## Step 4: Surface judgment cues, don't compute "usefulness"

After the table, add a short note in plain prose:
- Mention rules that haven't fired (compare against `.ast-grep/*.yml` files vs rules in log) — they may be candidates to delete OR they may be silently effective (Claude doesn't try the bad pattern anymore).
- Mention rules with very high fire counts on the same file — may indicate Claude keeps trying the same shortcut, or the rule is too broad.
- Don't compute a "useful score." Surface the data, let the user decide.
