import { serve } from '@hono/node-server';
import {
  createApp,
  DEFAULT_MAX_PAYLOAD_BYTES,
  DEFAULT_TTL_SECONDS,
  parseSize,
} from './app';
import { MemoryStore } from './memory_store';

const app = createApp(new MemoryStore(), {
  maxPayloadBytes: parseSize(
    process.env.MAX_PAYLOAD_BYTES,
    DEFAULT_MAX_PAYLOAD_BYTES,
  ),
  ttlSeconds: parseSize(process.env.TTL_SECONDS, DEFAULT_TTL_SECONDS),
});

const port = parseSize(process.env.PORT, 8787);

serve({ fetch: app.fetch, port });
