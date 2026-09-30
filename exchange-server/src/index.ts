export interface Env {
  TRANSFERS: KVNamespace;
  MAX_PAYLOAD_BYTES?: string;
  TTL_SECONDS?: string;
}

const TOKEN_BYTES = 32;
const DEFAULT_MAX_PAYLOAD_BYTES = 1024 * 1024;
const DEFAULT_TTL_SECONDS = 15 * 60;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/v1/transfers" && request.method === "POST") {
      return upload(request, env);
    }
    const prefix = "/v1/transfers/";
    if (url.pathname.startsWith(prefix) && request.method === "GET") {
      return download(url.pathname.slice(prefix.length), env);
    }
    return json({ error: "not_found" }, 404);
  },
};

async function upload(request: Request, env: Env): Promise<Response> {
  const maxBytes = parseSize(env.MAX_PAYLOAD_BYTES, DEFAULT_MAX_PAYLOAD_BYTES);
  const payload = await request.text();
  if (new TextEncoder().encode(payload).length > maxBytes) {
    return json({ error: "payload_too_large" }, 413);
  }

  const token = generateToken();
  const ttl = parseSize(env.TTL_SECONDS, DEFAULT_TTL_SECONDS);
  await env.TRANSFERS.put(token, payload, { expirationTtl: ttl });

  const expiresAt = new Date(Date.now() + ttl * 1000).toISOString();
  const transferUrl = `${new URL(request.url).origin}/v1/transfers/${token}`;
  return json({ url: transferUrl, expiresAt }, 201);
}

async function download(token: string, env: Env): Promise<Response> {
  const payload = await env.TRANSFERS.get(token);
  if (payload === null) {
    return json({ error: "not_found" }, 404);
  }
  await env.TRANSFERS.delete(token);
  return new Response(payload, {
    headers: { "Content-Type": "application/octet-stream" },
  });
}

function generateToken(): string {
  return base64url(crypto.getRandomValues(new Uint8Array(TOKEN_BYTES)));
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function parseSize(value: string | undefined, fallback: number): number {
  if (value === undefined) return fallback;
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
