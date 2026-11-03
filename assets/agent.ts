import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { defaultSettingsMiddleware, wrapLanguageModel } from "ai";
import { defineAgent } from "eve";

const nearai = createOpenAICompatible({
  name: "nearai",
  baseURL: "https://cloud-api.near.ai/v1",
  apiKey: process.env.NEARAI_API_KEY,
});

export default defineAgent({
  // Any model from NEAR AI's catalog works. eve cannot look up its context window, so it is set here.
  // NEAR AI stops a response at 4096 tokens when no max_tokens is sent, which cuts a long deliverable mid-sentence.
  model: wrapLanguageModel({
    model: nearai.chatModel("anthropic/claude-opus-5-5"),
    middleware: defaultSettingsMiddleware({ settings: { maxOutputTokens: 32_000 } }),
  }),
  // Compaction starts near 90% of this, so a smaller window keeps each step's input bounded.
  modelContextWindowTokens: 300_000,
  // These caps only stop a runaway session; size them from the price (see the skill's nearai.md).
  limits: {
    maxInputTokensPerSession: 15_000_000,
    maxOutputTokensPerSession: 600_000,
  },
});
