# Repo shapes: how a repo becomes an agent

First find what the repo gives the agent: knowledge (a procedure, prompts, references), an executable (a CLI or a library), or a service (an MCP or HTTP API). Most repos are one of the shapes below. A repo can mix shapes. For example, a skill can come with scripts that need a Python package.

## License gate (before anything else)

| License | What to do |
|---|---|
| MIT, Apache-2.0, BSD, ISC, Unlicense, CC0 | Fine. Keep the LICENSE file next to the vendored copy and credit the author in the bio ("Built on the open-source [repo](url) by <author>"). |
| GPL, LGPL, MPL | Running it as a service is allowed. Keep the LICENSE file and credit the author. Tell the user in one line. |
| AGPL | The network clause applies. The vendored source, with your changes, must be offered to the agent's users, so keep the project public. Tell the user before going on. |
| CC-BY-NC, any "non-commercial" or "no derivatives" license, or no license at all | **Stop.** Selling the agent needs the author's permission. Tell the user and wait. |

## Shapes

### A. Agent skill: `SKILL.md`, for Claude, Codex or the Agent Skills standard

Kinship Research was built this way.

- Vendor the skill directory into `agent/skills/<skill-name>/`.
  - The name may use only ASCII letters, digits, `_` and `-`, at most 64 characters.
  - Copy `SKILL.md` with its `references/`, `assets/`, `scripts/` and `LICENSE`.
  - Leave out repo noise: CI, images, tests and the README, unless the skill reads them.
- The packaged `SKILL.md` must have `description` frontmatter. eve ignores any other frontmatter fields.
- In the sandbox the files are at `$HOME/.agents/skills/<skill-name>/`. Paths inside `SKILL.md` resolve relative to that directory.
- In `instructions.md`, tell the agent to load the skill at the start of every job (`eve__skill`).
- Adapt the skill (see below). Keep your changes small, so that a later upstream version can be merged in.

### B. Prompt, method or knowledge pack: markdown files, no runtime

- Put the core rules into `agent/instructions.md`, adapted to the market sections of the skeleton.
- Put the rest into `agent/skills/<topic>.md` files, or one packaged skill, so the model loads them only when it needs them.

### C. CLI tool or library in Python, Go or another language, run as a command

- Install it in the sandbox image with `agent/sandbox.ts` (start from `assets/sandbox.ts`). eve runs `prepare` once at build time and snapshots the result, so every job starts with the tool installed.
  - **Pin it:** `pip install "git+https://github.com/o/r@<sha>"`, or `git clone` and then `git checkout <sha>`.
  - **Python:** use `python3 -m pip install --user --break-system-packages …`. `python3 -m venv` fails in the local Docker image: it is Ubuntu with Python 3.14, has no `python3-venv`, and its Python is externally managed. Console scripts land in `~/.local/bin`, which is on the sandbox PATH.
    - In the local image `~/.local/share` belongs to root, so a package that ships man pages (matplotlib through fonttools) fails with "Permission denied". Run this first: `mkdir -p ~/.local/share 2>/dev/null; [ -w ~/.local/share ] || sudo chown -R "$(id -u):$(id -g)" ~/.local/share`.
    - Verified on Vercel on 2026-11-04 (Token Deep Dive): the same commands install matplotlib in `prepare` during `vercel deploy`. Pin a version range rather than an exact version, because the Python version differs between the local image and Vercel.
  - **System packages:** the systems differ. Locally the sandbox is Docker (`ghcr.io/vercel/eve`, Ubuntu, `sudo apt-get`); on Vercel it is Amazon Linux (`sudo dnf`). Prefer pip or npm packages. If you need a system package, branch on `command -v dnf`.
  - **Test `prepare` locally:** run `smoke-local.sh` with a brief that runs the tool. On Vercel, `prepare` runs during `vercel deploy`; a failure there fails the build, so read the deploy log.
- Write a short skill, `agent/skills/<tool>/SKILL.md`. It covers the commands the job needs, the inputs, the outputs, and the common errors. The agent calls the tool through `bash`.
- If the agent calls a command many times with typed input, wrap it in `agent/tools/<name>.ts`. Use `ctx.getSandbox()`, then `sandbox.run({ command })`. A typed tool is easier for the model than raw bash.

### D. TypeScript or JavaScript library

- Add it as a pinned npm dependency (`npm i --ignore-scripts <pkg>@<version>`). Call it from `agent/tools/*.ts` with `defineTool`. It runs in the Vercel function, not in the sandbox.

### E. MCP server

- **Hosted, with an HTTPS URL.** Add `agent/connections/<name>.ts` with `defineMcpClientConnection({ url, description, auth })`. The model finds its tools with `eve__search("<name>__")`.
- **Hosted, but its keyed endpoint wants OAuth in a browser.** The agent cannot do that flow. CoinGecko's Pro MCP server is one: it answers 401 with `www-authenticate: Bearer realm="OAuth"` and ignores the API key in a header. Use the service's plain HTTP API instead (shape F).
- **Stdio only.** eve connections cannot start a local process. Choose one of these:
  1. use the CLI or library under the server and handle it as shape C or D;
  2. port the few tools the job needs to `agent/tools/*.ts`;
  3. host the server yourself. That is outside this skill: ask the user first.

### F. HTTP API with an OpenAPI document

- Add `agent/connections/<name>.ts` with `defineOpenAPIConnection({ spec, baseUrl?, auth })`.
- If the API needs a key, the builder pays for its usage. Put the key in `.env.local`, push it with `push-env.sh`, and count its cost in the price.
- **For a data API the agent analyses, write a tool instead.** Token Deep Dive (`~/Developer/token-deep-dive/agent/tools/coingecko.ts`) shows the pattern: one GET tool with the key in a header, and a `saveAs` input that writes the response into the sandbox and returns only an outline.
  - The key stays in the function and never enters the sandbox.
  - A year of daily prices or a 300 KB list reaches Python as a file instead of filling the model's context.
  - Pair it with a script in the skill that computes every number and draws the charts, so the model copies numbers rather than calculating them.
- **Check what the key's plan answers before you write the method.** Call each endpoint the job needs once with the real key. Plans hide endpoints behind 401s; list those in the skill as "do not call".

## Bad fits: tell the user before you build

- **Needs a GPU, a desktop GUI or an interactive browser.** Vercel Sandbox has none of them.
- **Runs as a long-lived server or daemon.** The agent runs for the length of a job, not continuously.
- **Acts in the customer's own accounts.** Posting, emailing, or changing their systems is possible only through services the customer connects to the job; the market MCP exposes them. Never collect customers' credentials.
- **Mostly scrapes sites behind logins or CAPTCHAs.** The agent may not get past them.
- **Its main output is files of more than 100 MiB, or more than 5 files.** That is the market's limit on files per deliverable.

## Adapting a vendored skill

Make these changes in the vendored copy:

- **Tool names.** Claude Code's `WebSearch`, `WebFetch` and `Bash` become `web_search`, `web_fetch` and `bash`. Delete the instructions for tools the agent does not have, such as a browser, computer use or `AskUserQuestion`.
- **Questions to the user.** "Ask the user" becomes "ask at most three questions in your first thread message, each with a default, and do not wait". A job runs on its own; the customer may answer hours later or never.
- **Self-update steps.** Remove them or tell the agent to skip them, because the version is pinned. Kinship's skill had an "Обновления навыка" step for this.
- **Local paths.** Paths such as `~/.claude/skills/...` become `$HOME/.agents/skills/<skill-name>/...`. The working directory for the job is `/workspace`.
- **Interactive loops.** "Show me the plan and wait for approval" and similar steps become: decide, write the decision down, and go on.
- **Output.** The skill's final artifact must fit the market's deliverable: Markdown up to 256 KiB, plus up to 5 files uploaded through the market.
- Record every change in `SOURCE.md` (scaffold creates it), so a later upstream update can be merged by hand.
