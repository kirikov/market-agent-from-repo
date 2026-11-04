# NEAR AI Cloud: model, limits, credits

The endpoint is OpenAI-compatible: `https://cloud-api.near.ai/v1`. Authenticate with `NEARAI_API_KEY`. The template connects through `@ai-sdk/openai-compatible`.

## Model

- List the models: `curl -sS https://cloud-api.near.ai/v1/models` (no key needed). Model ids have a provider prefix, for example `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5` or `anthropic/claude-haiku-5-5`.
- **Default: `anthropic/claude-opus-5-5`.**
  - Use Sonnet for cheap, high-volume jobs.
  - Use Haiku only for simple transforms.

## The 4096-token trap

If a request sends no `max_tokens`, NEAR AI stops Anthropic models at **4096 output tokens** with `finish_reason: length`. eve sends none, so a long deliverable comes out cut mid-sentence. This hit Kinship's first real job: the report stopped at "Обраща…". Sonnet 5.5 stops the same way: `length` at exactly 4096, measured 2026-11-03; with the fix it gave a 8147-token `stop`.

`assets/agent.ts` fixes it with a default output limit:

```ts
model: wrapLanguageModel({
  model: nearai.chatModel("anthropic/claude-opus-5-5"),
  middleware: defaultSettingsMiddleware({ settings: { maxOutputTokens: 32_000 } }),
}),
```

Keep this for every model. Use 32k for Opus and Sonnet; a deliverable of up to 256 KiB fits.

## Context window and session limits

- Set `modelContextWindowTokens` yourself: eve cannot look it up for a custom provider. 300k worked for Opus 5.5. A smaller window keeps each step's input bounded, because compaction starts near 90 % of it.
- `limits.maxInputTokensPerSession` and `limits.maxOutputTokensPerSession` stop a runaway session. Size them from the money, not the time:

  ```
  budget_usd       ≈ 0.4 × price_usd          (leave room for the 5 % market fee and margin)
  max_input_tokens ≈ budget_usd / input_price_per_token
  ```

  Without prompt caching, a 1-hour research job on Opus reads several million input tokens, because the context is re-read on every step. Kinship used 15M input and 600k output as a safety cap at a $25 price. Check the real spend of the test hire on cloud.near.ai, then adjust the price or the caps.
- NEAR AI's `usage` reports no cached tokens (checked 2026-11-04: two identical 20k-token Opus requests both counted the full 20k as `prompt_tokens`). Size the caps assuming every step pays for its full context.
- **Time box.** Put the job length in the instructions: "one job is about N minutes; at about 0.8·N stop starting new work and write the deliverable". It controls cost better than token caps.

## Credits

- When the account runs out, NEAR AI answers **402** "Credit limit exceeded". The turn fails, and the template declines the job and refunds the customer automatically. That happened on Kinship's first real job.
- Before a test hire, and before going live, check with a tiny call; `scripts/preflight.sh` does it:

  ```bash
  curl -sS https://cloud-api.near.ai/v1/chat/completions -H "authorization: Bearer $K" \
    -H 'content-type: application/json' \
    -d '{"model":"anthropic/claude-haiku-5-5","max_tokens":5,"messages":[{"role":"user","content":"ok"}]}'
  ```

- After the user tops up, a declined job does not come back: hire the agent again. Put the customer's earlier thread answers into the new brief, because the new job has its own thread.
