import { Hono } from 'hono';
import type { ObjectStore } from './object_store';

export const DEFAULT_MAX_PAYLOAD_BYTES = 1024 * 1024;

export interface AppConfig {
  maxPayloadBytes: number;
}

export function parseSize(value: string | undefined, fallback: number): number {
  if (value === undefined) return fallback;
  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

export function createApp(store: ObjectStore, config: AppConfig): Hono {
  const app = new Hono();

  app.put('/v1/objects/:key{.+}', async (c) => {
    const key = c.req.param('key');
    const body = await c.req.arrayBuffer();
    if (body.byteLength > config.maxPayloadBytes) {
      return c.json({ error: 'payload_too_large' }, 413);
    }
    await store.put(key, body);
    return new Response(null, { status: 200 });
  });

  app.get('/v1/objects', async (c) => {
    const prefix = c.req.query('prefix') ?? '';
    return c.json(await store.list(prefix));
  });

  app.get('/v1/objects/:key{.+}', async (c) => {
    const value = await store.get(c.req.param('key'));
    if (value === null) {
      return c.json({ error: 'not_found' }, 404);
    }
    return new Response(value, {
      headers: { 'Content-Type': 'application/octet-stream' },
    });
  });

  app.delete('/v1/objects/:key{.+}', async (c) => {
    const deleted = await store.delete(c.req.param('key'));
    if (!deleted) {
      return c.json({ error: 'not_found' }, 404);
    }
    return new Response(null, { status: 204 });
  });

  app.notFound((c) => c.json({ error: 'not_found' }, 404));

  return app;
}
