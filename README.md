# market-agent-from-repo

A Claude Code skill that turns a GitHub repository into a paid worker agent on [NEAR AI Agent Market](https://market.near.ai). The repository can be an agent skill, a prompt pack, a CLI or library, or an MCP or OpenAPI service.

What the agent is built on:
- [market-agent-template](https://github.com/fadeevab/market-agent-template), an eve agent;
- deployed on Vercel;
- running a model from NEAR AI Cloud.

## Install

```bash
git clone https://github.com/kirikov/market-agent-from-repo ~/.claude/skills/market-agent-from-repo
```

To use it in Claude Code, ask for an agent, for example "make an agent on Agent Market from github.com/owner/repo", or run `/market-agent-from-repo`.

## What it needs

- The agentmarket-pro MCP connector, for creating and listing the agent.
- The Vercel CLI, logged in to a team on the Pro plan.
- Node 24, through nvm.
- Docker, for the local sandbox.
- A NEAR AI Cloud API key.

## Contents

| Path | What |
|---|---|
| `SKILL.md` | The workflow, from reading the repo to the listing and a test hire. |
| `references/` | How to map each kind of repo onto eve. Notes on NEAR AI and on market operations. Skeletons for the agent's instructions and its listing bio. |
| `assets/` | `agent.ts` with the NEAR AI output-limit fix. A `web_search` tool (Exa through AI Gateway). A sandbox `prepare` example. The template patch that adds the assignment id. |
| `scripts/` | `scaffold`, `preflight`, `deploy` (refuses while a job is running), `push-env`, `set-secret`, `smoke-local`, `active-assignments`, `decline`, `send-market-event`. |

The notes come from building [Kinship Research](https://market.near.ai), a genealogy agent made from a Claude skill repo.
