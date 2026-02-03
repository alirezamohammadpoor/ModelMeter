# Usage Data Discovery (2026-02-02)

## Search summary
Searched local Claude Code data directories for usage/quota files.
No explicit "usage.json" or "quota" file found.

## Candidate files found
1) `~/.claude/stats-cache.json`
   - Contains `dailyActivity[]` and `dailyModelTokens[]`.
   - Suitable for deriving daily + weekly totals from local activity.

2) `~/.claude/projects/*/sessions-index.json`
   - Session metadata (session ids, timestamps, message counts).
   - Not a direct quota/limit file, but could be used to compute activity totals.

3) `~/.claude/projects/*/*.jsonl`
   - Raw session logs; large and not ideal for polling.

## Proposed data source (for MVP)
Use a command-driven source that returns percent values (API/CLI based).
The command is configured in `~/.menuusage/config.json` under `providerCommand`.
Output format expects either `sessionPercent`/`weeklyPercent` or progress lines with `max: 100`.

## Wrapper template
Use `MenuUsage/scripts/usage_wrapper.py` to adapt provider JSON into the expected format.

Example config:
```
{
  "source": "command",
  "claudeCommand": "/Users/alirezamohammadpoor/Desktop/repos/CodexBar/MenuUsage/scripts/claude_usage.py",
  "codexCommand": "/Users/alirezamohammadpoor/Desktop/repos/CodexBar/MenuUsage/scripts/codex_usage.py"
}
```

## Open question (if needed)
If you have a more direct usage/quota file, provide the path and schema.
