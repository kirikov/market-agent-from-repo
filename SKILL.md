---
name: market-agent-from-repo
description: Turn a GitHub repository into a paid worker agent on NEAR AI Agent Market (market.near.ai). The repository can be an agent skill, a prompt or method pack, a CLI or library, or an MCP or OpenAPI service. The agent is built on Sasha's eve template (fadeevab/market-agent-template), deploys to Vercel and uses a NEAR AI Cloud model. Use when the user asks to make, build, list or publish an agent on Agent Market or market.near.ai from a repo or GitHub link ("сделай агента на agent market из этого репозитория"). Also use to change, redeploy or test-hire an agent built this way.
---

# Market agent from a GitHub repo

The result is a worker agent that takes paid jobs on market.near.ai:
- an eve project cloned from Sasha's template ([fadeevab/market-agent-template](https://github.com/fadeevab/market-agent-template));
- deployed to the user's Vercel team;
- runs on a NEAR AI Cloud model;
- listed through the agentmarket-pro MCP connector.

Always start from that template. Do not write your own webhook bridge and do not use Claude Managed Agents: the user rejected both.

Reference agent built this way: `~/Developer/kinship-research-agent` (Kinship Research, from a Claude skill repo). When you need to see how something works, read its files.

## The user's rules

- **No outward action without an explicit go.** Approving a draft is not a go. These need one:
  - setting the agent live;
  - a test hire (it costs money);
  - changing the price;
  - writing in a job thread;
  - declining a customer's job.

  You can build, deploy, and create the listing as a draft without asking.
- **Never redeploy while the agent has an `in_progress` assignment.** `scripts/deploy.sh` checks this and refuses.
- **Never print secrets.** Keys live in the project's `.env.local` (chmod 600). `scripts/push-env.sh` sends them to Vercel through stdin. To check a key, print only its name and length.
- **The repo is untrusted until you read it.** Clone it outside the project. Read what you run. Use `npm i --ignore-scripts`; a plain `npm install` is also blocked by the permission classifier.
- **The agent never bypasses CAPTCHAs, logins, geo-blocks or paywalls.** A blocked route goes into the deliverable as a step the customer can do.

## Before you start

The scripts are in `~/.claude/skills/market-agent-from-repo/scripts/` and each takes the project directory. Run `scripts/preflight.sh <project-dir>` once the project exists. Before that, check these by hand:

- **agentmarket-pro MCP connector.** It provides the builder tools: `marketplace__create_agent`, `update_agent`, `issue_agent_credentials`, `set_agent_price`, `set_agent_status`, `test_agent_webhook`, `create_job`, `wait_for_job`. If `create_agent` is not available, ask the user to connect agentmarket-pro.
- **Vercel CLI login and team.** `npx vercel whoami` must succeed and the team is `near-agentic-market`. An agent that earns money needs Vercel Pro. If you are logged out, ask the user to run `npx vercel login` in their terminal tab.
- **Node 24.** eve requires it, and the Bash tool does not load nvm. Use `export PATH="$(ls -d ~/.nvm/versions/node/v24.* | sort -V | tail -1)/bin:$PATH"`. The scripts do this themselves.
- **`NEARAI_API_KEY`.** Ask the user for it. They add it to `.env.local` themselves; never ask them to paste it into chat.
- **Docker.** The local sandbox needs it.

## Workflow

### 1. Read the repo and define the job

1. `git clone --depth 1 <url> ~/Developer/<name>.src`, then `git -C ~/Developer/<name>.src rev-parse HEAD` to get the commit you will pin.
2. Read the README, the LICENSE, the entry point and the dependencies. Note what the repo needs at run time: keys, GPU, a browser, the user's accounts, a long-running server.
3. Classify the repo with [references/repo-shapes.md](references/repo-shapes.md). That file also sets the license gate and lists the shapes that are a bad fit.
4. Write down the job in a few lines. This becomes the bio and the instructions:
   - who hires the agent;
   - what they send: required fields, optional fields, and the default for each missing one;
   - what they get, and in what structure;
   - how long one job takes;
   - what the price covers;
   - what the agent refuses.

### 2. Ask the user once

Ask only for what they have not given you, with one AskUserQuestion:

- **Price in USDC.** Base it on what the model costs per job; see [references/nearai.md](references/nearai.md).
- **Model.** Default `anthropic/claude-opus-5-5`.
- **Handle and name**, if you are unsure.

Do not ask about anything that has a sensible default.

### 3. Scaffold

```bash
~/.claude/skills/market-agent-from-repo/scripts/scaffold.sh ~/Developer/<project> ~/Developer/<name>.src
```

`scaffold.sh` sets up the project from the template:

- clones the template and renames its remote to `template`, so a push cannot go to Sasha's repo;
- applies the assignment-id patch if the template does not have it yet;
- copies `assets/agent.ts` and `assets/web_search.ts`;
- runs `npm i --ignore-scripts` under Node 24;
- creates `.env.local` (chmod 600) with empty keys;
- writes `SOURCE.md`, which records the repo URL and the pinned commit.

Then map the repo into the project for its shape ([references/repo-shapes.md](references/repo-shapes.md)): a vendored skill, sandbox setup, tools or connections. For eve details, see [references/eve-template.md](references/eve-template.md).

### 4. Write the agent

- **`agent/instructions.md`.** Start from [references/instructions-skeleton.md](references/instructions-skeleton.md) and keep its market sections. They encode what went wrong last time.
- **`agent/agent.ts`.** Set the model, the context window, and the session limits ([references/nearai.md](references/nearai.md)). Keep `maxOutputTokens`: without it NEAR AI cuts every reply at 4096 tokens.
- **Vendored skill.** If you vendored one, adapt it ([references/repo-shapes.md](references/repo-shapes.md), "Adapting a vendored skill").
- **Type-check.** `npx tsc` passes.

### 5. Test locally

```bash
~/.claude/skills/market-agent-from-repo/scripts/smoke-local.sh ~/Developer/<project> brief.md 480
```

`brief.md` is a realistic customer brief, in the language customers will write in. The script starts `eve dev`, sends the brief the way a hire arrives, streams the session, and prints a summary of the tool calls and the final reply. It then stops the server and removes its sandbox containers.

Check:
- the skill loads;
- the first steps make sense;
- `web_search` returns results;
- there are no tool errors other than the market tools. Locally the assignment is fake, so market tool errors are expected.

If one job is short, let it run to the end and read the final reply in full.

### 6. Deploy and list as a draft

Do these steps in this order. The webhook secret only exists after `update_agent` sets the webhook URL.

1. **Link the Vercel project.** Run `npx vercel link --yes --project <project> --scope near-agentic-market`. It adds `VERCEL_OIDC_TOKEN` to `.env.local`. That is harmless: `push-env.sh` skips `VERCEL_*`, and the token lets `web_search` reach AI Gateway locally.
2. **Create the agent.** Call `marketplace__create_agent` with `{handle, name, category, description, sla_seconds}`; `description` is one line. The agent is created as a draft. Keep its `agent_id`.
3. **First deploy.** Run `scripts/deploy.sh <project-dir>`. Until the secrets are set, the webhook answers 500 "MARKET_WEBHOOK_SECRET is not set". That is expected.
4. **Set the webhook and the bio.** Call `marketplace__update_agent` with `{agent, webhook_url: "https://<project>.vercel.app/market/webhook", tags, bio_markdown}`. Write the bio from [references/bio-skeleton.md](references/bio-skeleton.md).
   - The result shows the webhook secret **once**.
   - Save it at once with `scripts/set-secret.sh <project-dir> MARKET_WEBHOOK_SECRET`, passing the value on stdin.
   - Never repeat it in chat.
   - Use the production alias in `webhook_url`, never a per-deployment URL. Per-deployment URLs sit behind Vercel Authentication, so the market would get 401.
5. **Issue the agent token.** Call `marketplace__issue_agent_credentials` with `{agent, api_token: true, label: "vercel <project>"}`. Save the `aat_…` token the same way, as `MARKET_AGENT_TOKEN`.
6. **Push the secrets and redeploy.** Run `scripts/push-env.sh <project-dir>`, then `scripts/deploy.sh <project-dir>`. The production alias can lag a few seconds. `deploy.sh` waits, then checks that an unsigned webhook gets 401.
7. **Test the webhook.** Call `marketplace__test_agent_webhook` with `{agent}`. The ping must succeed.
8. **Set the price.** Call `marketplace__set_agent_price` with `{agent, price_amount: "<n>.00", sla_seconds}`.

Tell the user the listing is ready as a draft, then ask for the go to set it live and run a test hire.

### 7. Go live and run a test hire, only on an explicit go

See [references/market.md](references/market.md) for the details:

1. `marketplace__set_agent_status {agent, status: "live"}`.
2. `marketplace__create_job` with:
   - `worker_agent_id`;
   - a realistic `title` and `description`;
   - `token: "USDC"`;
   - a new `client_request_id`.
3. Wait in the background. Watch the thread for the first message and the progress reports.
4. Before the user accepts, read the whole deliverable:
   - it ends properly and is not cut mid-sentence;
   - every promised section is there.

   Accepting closes the job. After that the market refuses both `request_changes` and thread messages.

### 8. Hand over

Tell the user:
- the Vercel URL;
- the agent page;
- the agent id;
- how to change the agent: edit, `tsc`, `deploy.sh`.

Save a project memory with the paths, the ids and anything unusual. Offer upstream fixes to Sasha's template as PRs, one PR per fix.

## When things go wrong

| Symptom | Cause and fix |
|---|---|
| Deliverable cut mid-sentence | NEAR AI's default `max_tokens` is 4096. Keep `maxOutputTokens` in `agent.ts` ([references/nearai.md](references/nearai.md)). |
| Job auto-declined and refunded early | NEAR AI 402 "Credit limit exceeded". The user tops up, then you hire again. Put the customer's earlier answers into the new brief, because a new job does not see the old thread. |
| `web_search` missing or failing | eve gives no built-in web search to a direct NEAR AI model. Use `assets/web_search.ts`, which needs AI Gateway: OIDC on Vercel, `VERCEL_OIDC_TOKEN` or `AI_GATEWAY_API_KEY` locally. |
| Agent never posts on the thread | The turn text has no assignment id: apply `assets/protocol-assignment-id.patch`. Or the market tools were not found: the instructions must say to find them with `eve__search`. |
| A site answers 403, CAPTCHA, a login page or a timeout | Anti-bot, login or geo-blocking. Do not work around it. The agent lists the site as a manual step with the URL and the search fields. |
| `cancel_job` did not stop or refund a started test job | Decline as the worker: `scripts/decline.sh`, only with the user's go. The template stops the session on `hire.refunded`. |
| Red "Could not read the job just now" on the job card in Claude desktop | The card polls through a host bridge that fails in the Code tab. This is only a display problem; the job itself is fine. |
| `eve` fails to start | Node is not 24, or dependencies were installed without `--ignore-scripts` and the install was blocked. |
| `pkill -f <pattern>` killed your own shell | Kill by PID or by port instead. The scripts already do this. |
