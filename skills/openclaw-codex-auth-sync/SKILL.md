---
name: openclaw-codex-auth-sync
description: Synchronize OpenClaw openai-codex OAuth profiles from the current Codex ChatGPT login tokens and enforce OpenClaw default model as openai-codex/gpt-5.3-codex. Use when a user asks to switch OpenClaw to login/OAuth mode, replace auth after re-login or account change, repair mismatched OpenClaw auth, or force the strongest Codex model as default.
---

# OpenClaw Codex Auth Sync

## Workflow

1. Confirm Codex is in ChatGPT login mode:
   - Run `codex login status`.
   - Proceed only when output shows `Logged in using ChatGPT`.

2. Run the sync script:
   - `bash scripts/sync_openclaw_codex_auth.sh`
   - This updates all `~/.openclaw/agents/*/agent/auth-profiles.json` entries for `openai-codex:default`.
   - This also updates `~/.openclaw/openclaw.json` to:
     - set auth profile mode to OAuth for `openai-codex:default`
     - set default model to `openai-codex/gpt-5.3-codex`
     - update `agents.list[*].model` when present
   - Gateway restart is executed by default.

3. Verify effective state:
   - `openclaw models status --json`
   - Ensure:
     - `defaultModel` is `openai-codex/gpt-5.3-codex`
     - OAuth profile label shows the expected email

4. Apply security hygiene:
   - Never print or echo raw `id_token`, `access_token`, or `refresh_token`.
   - If a user pasted a callback URL containing tokens, advise token rotation by re-login (`codex logout` then `codex login`).

## Commands

- Default run:
  - `bash scripts/sync_openclaw_codex_auth.sh`

- Dry run:
  - `bash scripts/sync_openclaw_codex_auth.sh --dry-run`

- Skip gateway restart:
  - `bash scripts/sync_openclaw_codex_auth.sh --no-restart`

- Use custom paths:
  - `bash scripts/sync_openclaw_codex_auth.sh --codex-auth /path/auth.json --openclaw-home /path/.openclaw`

- Also normalize session cached model fields (optional):
  - `bash scripts/sync_openclaw_codex_auth.sh --sync-sessions`

## Notes

- The script writes under `~/.openclaw`, so sandboxed environments may require elevated permission.
- The script requires `jq` and `python3`.
