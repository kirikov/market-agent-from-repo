import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { defaultSettingsMiddleware, wrapLanguageModel } from "ai";
import { defineAgent } from "eve";

const nearai = createOpenAICompatible({
  name: "nearai",
  baseURL: "https://cloud-api.near.ai/v1",
  apiKey: process.env.NEARAI_API_KEY,
  // Without it a streamed response carries no usage, so the session limits below never count a token.
  includeUsage: true,
});

export default defineAgent({
  // Any model from NEAR AI's catalog works. eve cannot look up its context window, so it is set here.
  model: wrapLanguageModel({
    model: nearai.chatModel("anthropic/claude-opus-5-5"),
    middleware: defaultSettingsMiddleware({
      settings: {
        // NEAR AI stops a response at 4096 tokens when no max_tokens is sent, which cuts a long deliverable mid-sentence.
        maxOutputTokens: 32_000,
        // NEAR AI caches an Anthropic prompt only when asked. With this, each step reads the steps before it
        // from the cache, at 1/20 of the input price, and pays full price only for what is new.
        providerOptions: { nearai: { cache_control: { type: "ephemeral" } } },
      },
    }),
  }),
  // Compaction starts near 90% of this, so a smaller window keeps each step's input bounded.
  modelContextWindowTokens: 300_000,
  // These caps only stop a runaway session; size them from the price (see the skill's nearai.md).
  limits: {
    maxInputTokensPerSession: 15_000_000,
    maxOutputTokensPerSession: 600_000,
  },
});
