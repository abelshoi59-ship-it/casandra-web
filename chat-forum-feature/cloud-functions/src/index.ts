import Anthropic from "@anthropic-ai/sdk";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

initializeApp();

// Stored via: firebase functions:secrets:set ANTHROPIC_API_KEY
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");

// The in-app automotive assistant persona.
const SYSTEM_PROMPT = `You are Casandra, an in-app assistant for an automotive companion app.
Help drivers with their vehicles: maintenance schedules, warning lights, fuel and
efficiency, trip planning, and finding nearby service. Be concise and practical.
When you don't have a specific fact about the user's vehicle, say so and ask for it.
Never invent maintenance figures or recall information.`;

// Optional tool the model can call to pull the signed-in user's vehicle context.
// Wire `get_vehicle_context` to your own data source (Firestore, your API, etc.).
const TOOLS: Anthropic.Tool[] = [
  {
    name: "get_vehicle_context",
    description:
      "Get the signed-in user's saved vehicle details (make, model, year, mileage) " +
      "and recent maintenance history. Call this whenever an answer depends on the " +
      "user's specific car.",
    input_schema: {
      type: "object",
      properties: {},
    },
  },
];

interface ClientMessage {
  role: "user" | "assistant";
  content: string;
}

/**
 * Look up the caller's vehicle context. Replace the stub with a real read
 * (e.g. Firestore `users/{uid}/vehicles`). Returning structured text is fine —
 * the model reads it as the tool result.
 */
async function getVehicleContext(uid: string): Promise<string> {
  // TODO: read from your data source keyed by `uid`.
  return JSON.stringify({
    note: "No vehicle on file yet. Ask the user for make/model/year.",
    uid,
  });
}

/**
 * POST /aiAssistantStream
 * Headers: Authorization: Bearer <Firebase ID token>
 * Body: { messages: [{ role, content }, ...] }
 * Response: text/event-stream of { type: "delta", text } then { type: "done" }.
 */
export const aiAssistantStream = onRequest(
  { secrets: [ANTHROPIC_API_KEY], cors: true, timeoutSeconds: 120 },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // --- Auth: require a valid Firebase ID token ---
    const authHeader = req.get("Authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!token) {
      res.status(401).json({ error: "Missing bearer token" });
      return;
    }
    let uid: string;
    try {
      uid = (await getAuth().verifyIdToken(token)).uid;
    } catch {
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    const incoming = (req.body?.messages ?? []) as ClientMessage[];
    if (!Array.isArray(incoming) || incoming.length === 0) {
      res.status(400).json({ error: "messages[] required" });
      return;
    }

    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });

    // SSE setup
    res.setHeader("Content-Type", "text/event-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.setHeader("Connection", "keep-alive");
    const send = (obj: unknown) => res.write(`data: ${JSON.stringify(obj)}\n\n`);

    const messages: Anthropic.MessageParam[] = incoming.map((m) => ({
      role: m.role,
      content: m.content,
    }));

    try {
      // Agentic loop: stream text; if the model calls a tool, run it and continue.
      while (true) {
        const stream = client.messages.stream({
          model: "claude-opus-4-8", // swap to claude-sonnet-4-6 / claude-haiku-4-5 for lower cost
          max_tokens: 2048,
          system: SYSTEM_PROMPT,
          tools: TOOLS,
          messages,
        });

        stream.on("text", (delta) => send({ type: "delta", text: delta }));

        const final = await stream.finalMessage();

        if (final.stop_reason !== "tool_use") {
          break; // end_turn / max_tokens / refusal — we're done
        }

        // Execute any tool calls, feed results back, loop again.
        messages.push({ role: "assistant", content: final.content });
        const toolResults: Anthropic.ToolResultBlockParam[] = [];
        for (const block of final.content) {
          if (block.type === "tool_use" && block.name === "get_vehicle_context") {
            toolResults.push({
              type: "tool_result",
              tool_use_id: block.id,
              content: await getVehicleContext(uid),
            });
          }
        }
        messages.push({ role: "user", content: toolResults });
      }

      send({ type: "done" });
      res.end();
    } catch (err) {
      const message = err instanceof Error ? err.message : "unknown error";
      send({ type: "error", error: message });
      res.end();
    }
  }
);
