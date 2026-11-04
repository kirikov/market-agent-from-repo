import { defineTool } from "eve/tools";
import { z } from "zod";
import { marketBaseUrl, marketToken } from "../lib/market/env.js";

// The page's code goes to the customer as files, so it does not have to fit in one model reply.
// The upload runs here, outside the sandbox, so the agent token never enters it.
const MAX_MARKDOWN_BYTES = 250_000;

interface FileSlot {
  fileId: string;
  directUploadUrl: string;
  fileUrl: string;
}

export default defineTool({
  description:
    "Submit the deliverable: a Markdown summary plus 1-5 files from the sandbox (for example /workspace/site/index.html). Uploads the files to the market and submits them as a new version of the deliverable. Use it for every delivery, including after changes are requested.",
  inputSchema: z.object({
    assignmentId: z.string().uuid().describe("The assignment id from the job message."),
    markdownPath: z.string().describe("Sandbox path of the Markdown summary, e.g. /workspace/site/DELIVERY.md."),
    files: z.array(z.string()).min(1).max(5).describe("Sandbox paths of the files to deliver."),
  }),
  async execute({ assignmentId, markdownPath, files }, ctx) {
    const sandbox = await ctx.getSandbox();
    const markdown = await sandbox.readTextFile({ path: markdownPath });
    if (!markdown?.trim()) throw new Error(`${markdownPath} is missing or empty`);
    if (new TextEncoder().encode(markdown).length > MAX_MARKDOWN_BYTES) {
      throw new Error(`${markdownPath} is over 250 KB; shorten it`);
    }
    const delivered: Array<{ filename: string; url: string }> = [];
    for (const path of files) {
      const bytes = await sandbox.readBinaryFile({ path });
      if (!bytes?.length) throw new Error(`${path} is missing or empty`);
      const filename = path.split("/").pop() ?? path;
      const slot = (await market("POST", "/v1/files", { filename, byteSize: bytes.length, link: true })) as FileSlot;
      // The signed URL takes exactly byteSize bytes and no headers beyond the length.
      const put = await fetch(slot.directUploadUrl, { method: "PUT", body: Buffer.from(bytes) });
      if (!put.ok) throw new Error(`upload of ${filename} answered ${put.status}: ${(await put.text()).slice(0, 200)}`);
      await market("POST", `/v1/files/${slot.fileId}/complete`);
      delivered.push({ filename, url: slot.fileUrl });
    }
    await market("POST", `/v1/assignments/${assignmentId}/submit`, {
      deliverableMarkdown: markdown,
      files: delivered.map((file) => file.url),
    });
    return { submitted: true, files: delivered };
  },
});

async function market(method: "POST", path: string, body?: unknown): Promise<unknown> {
  const res = await fetch(new URL(path, marketBaseUrl()), {
    method,
    headers: { authorization: `Bearer ${marketToken()}`, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`market ${method} ${path} answered ${res.status}: ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}
