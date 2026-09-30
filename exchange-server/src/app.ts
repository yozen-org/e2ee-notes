import { Hono } from 'hono';
import type { TransferStore } from './transfer_store';

export const DEFAULT_MAX_PAYLOAD_BYTES = 1024 * 1024;
export const DEFAULT_TTL_SECONDS = 15 * 60;

export interface AppConfig {
  maxPayloadBytes: number;
  ttlSeconds: number;
}

export function parseSize(value: string | undefined, fallback: number): number {
  if (value === undefined) return fallback;
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function createApp(store: TransferStore, config: AppConfig): Hono {
  const app = new Hono();

  app.post('/v1/transfers', async (c) => {
    const payload = await c.req.text();
    if (new TextEncoder().encode(payload).length > config.maxPayloadBytes) {
      return c.json({ error: 'payload_too_large' }, 413);
    }
    const token = generateToken();
    await store.put(token, payload, config.ttlSeconds);
    const expiresAt = new Date(
      Date.now() + config.ttlSeconds * 1000,
    ).toISOString();
    const url = `${new URL(c.req.url).origin}/v1/transfers/${token}`;
    return c.json({ url, expiresAt }, 201);
  });

  app.get('/v1/transfers/:token', async (c) => {
    const payload = await store.consume(c.req.param('token'));
    if (payload === null) {
      return c.json({ error: 'not_found' }, 404);
    }
    return new Response(payload, {
      headers: { 'Content-Type': 'application/octet-stream' },
    });
  });

  app.notFound((c) => c.json({ error: 'not_found' }, 404));

  return app;
}

function generateToken(): string {
  return base64url(crypto.getRandomValues(new Uint8Array(32)));
}

function base64url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}
