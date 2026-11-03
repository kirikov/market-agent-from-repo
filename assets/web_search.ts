import { gateway, generateText, stepCountIs } from "ai";
import { defineTool } from "eve/tools";
import { z } from "zod";

// The NEAR AI model is a direct provider, so eve gives it no built-in web search. This tool runs
// Exa through AI Gateway instead (Vercel project OIDC on Vercel, VERCEL_OIDC_TOKEN or AI_GATEWAY_API_KEY
// locally), with a small Gateway model only to issue the provider-executed search call.
const DRIVER_MODEL = "google/gemini-2.5-flash-lite";

export default defineTool({
  // Add a domain hint to this description, e.g. which languages or sites to search.
  description:
    "Search the web. Returns up to 10 results with title, URL, date and the most relevant excerpts. Use several specific queries rather than one broad one. Use web_fetch or bash to read a page in full.",
  inputSchema: z.object({
    query: z.string().min(2).describe("The search query."),
    includeDomains: z
      .array(z.string())
      .optional()
      .describe("Only search these domains, e.g. ['github.com', 'arxiv.org']."),
    numResults: z.number().int().min(1).max(10).optional().describe("Results to return, default 8."),
  }),
  async execute({ query, includeDomains, numResults }) {
    const result = await generateText({
      model: DRIVER_MODEL,
      prompt: `Call exa_search once with exactly this query and nothing else:\n${query}`,
      tools: {
        exa_search: gateway.tools.exaSearch({
          type: "auto",
          numResults: numResults ?? 8,
          ...(includeDomains?.length ? { includeDomains } : {}),
          contents: { highlights: { maxCharacters: 1200 } },
        }),
      },
      toolChoice: "required",
      stopWhen: stepCountIs(1),
    });
    const output = result.toolResults.find((r) => r.toolName === "exa_search")?.output as
      | { results?: Array<Record<string, unknown>>; error?: unknown }
      | undefined;
    if (!output) return { query, results: [], error: "search returned nothing" };
    if (!output.results) return { query, results: [], error: output.error ?? output };
    return {
      query,
      results: output.results.map((r) => ({
        title: r.title,
        url: r.url,
        publishedDate: r.publishedDate ?? r.published_date,
        highlights: r.highlights ?? (typeof r.text === "string" ? r.text.slice(0, 1200) : undefined),
      })),
    };
  },
});
