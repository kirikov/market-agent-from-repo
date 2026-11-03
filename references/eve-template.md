# Sasha's template and eve: what matters

Template: https://github.com/fadeevab/market-agent-template. The market's "Deploy on Vercel" button clones it. It pins eve `0.76.0`. eve's own docs ship in `node_modules/eve/docs/`; read them there instead of guessing an API.

## Files

| File | What you do with it |
|---|---|
| `agent/instructions.md` | Rewrite it from `instructions-skeleton.md`. |
| `agent/agent.ts` | Replace it with `assets/agent.ts`, then set the model and the limits. |
| `agent/skills/` | Vendored skill(s): flat `<name>.md` or a packaged `<name>/SKILL.md`. |
| `agent/tools/*.ts` | One `defineTool` per file. The file name becomes the tool name. `web_search.ts` comes from the assets. |
| `agent/connections/*.ts` | `market.ts` is the market MCP: keep it. Add your own MCP or OpenAPI connections next to it. |
| `agent/sandbox.ts` | Optional: `prepare` installs what every job needs (`assets/sandbox.ts`). |
| `agent/sandbox/workspace/` | Optional: seed files copied into `/workspace`. |
| `agent/channels/market.ts`, `agent/lib/market/*` | The market protocol. Do not edit it, except for the assignment-id patch. |

## How the channel works

You need this to write the instructions:

- **One durable session per assignment.**
  - `hire.created` starts the session.
  - `hire.changes_requested` and `message.created` continue it.
  - `turnPolicy: "queue"`: a customer message waits for the running turn to end; it does not interrupt the turn.
- **When a turn ends, the channel asks the market about the assignment:**
  - still `in_progress`: it submits the final reply as the deliverable, or declines the job with a refund if the reply is empty;
  - anything else: it posts the final reply on the job thread (keep it under 4000 characters).
- **`hire.refunded`** (the buyer cancelled) cancels and resets the session, which frees the sandbox. This is the fix from PR fadeevab/market-agent-template#1, merged 2026-11-03.
- **Market tools come from the `market` connection,** named `marketplace__*`:
  - `marketplace__send_message`, `read_messages`, `report_progress`, `submit_deliverable`, `upload_file`, `confirm_upload`;
  - and the services the customer connected to the job.

  The model finds them with `eve__search`, so the instructions must say so.
- **The assignment id is not in the template's turn texts yet**, but the market tools need it. `assets/protocol-assignment-id.patch` adds it to all three texts, and the delivery deadline to the hire text. `scaffold.sh` applies the patch while the template lacks it. Upstream PR: fadeevab/market-agent-template#2, which also carries the `max_tokens` fix. Once it is merged, `scaffold.sh` skips the patch by itself.

## eve facts that bit last time

- **Node 24 or newer.** The Bash tool does not load nvm; put the v24 bin directory first in `PATH`.
- **Install dependencies with `npm i --ignore-scripts`.** Plain `npm install` is blocked as "code from external".
- **Built-in tools are `bash`, `read_file`, `write_file`, `web_fetch`, `eve__search`, `eve__tool` and `eve__skill`.** The built-in `web_search` exists only for AI Gateway models and for native OpenAI or Anthropic models. A NEAR AI model gets none, so the project needs `agent/tools/web_search.ts`.
- **`web_search.ts` runs Exa through AI Gateway,** with `google/gemini-2.5-flash-lite` as a small driver model.
  - On Vercel it uses the project's OIDC token.
  - Locally it needs `VERCEL_OIDC_TOKEN` (written by `vercel link`, and it expires after about 12 h; run `npx vercel env pull` or `link` again to refresh it) or `AI_GATEWAY_API_KEY`.
  - Gateway usage is billed to the Vercel team.
- **Sandbox.** It is rooted at `/workspace`; skill files are at `$HOME/.agents/skills/<skill>/`.
  - On Vercel it is a Vercel Sandbox, with open egress by default. Locally it is Docker; its containers are named `eve-sbx…`.
  - There is no browser and no GUI.
- **Context window.** eve cannot look up the context window of a model from a custom provider; set `modelContextWindowTokens` yourself. Compaction starts near 90 % of it.
- **Deploys and running sessions.** On Vercel, sessions are durable Vercel Workflows. A running session stays on the deployment it started on, so a redeploy does not break the session. The user still forbids redeploying during a job.

## Local run

```bash
export PATH="$(ls -d ~/.nvm/versions/node/v24.* | sort -V | tail -1)/bin:$PATH"
npx tsc                                   # must pass
npx eve dev --no-ui --port 2100 --logs warn
```

eve's HTTP API:

- `GET /eve/v1/health`;
- `POST /eve/v1/session {"message": "..."}`, which returns a `sessionId`;
- `GET /eve/v1/session/<id>/stream` (NDJSON events: `message.completed`, `turn.completed`, `turn.failed`, `step.failed`, `action.*`);
- `POST /eve/v1/session/<id>/cancel`.

`scripts/smoke-local.sh` wraps all of this.

Each sandbox `prepare` leaves an `eve-sandbox-template:*` Docker image (~430 MB) that later runs reuse. Remove the ones from abandoned experiments with `docker rmi`.

To test the market channel itself (a signed `hire.created` or `hire.refunded`), use `scripts/send-market-event.py <base_url> <event> <assignment_id> <project>/.env.local`. A fake assignment makes the turn-end settle step fail against the real market. That is expected locally.
