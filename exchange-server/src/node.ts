import { serve } from '@hono/node-server';
import { createApp, DEFAULT_MAX_PAYLOAD_BYTES, parseSize } from './app';
import { MemoryObjectStore } from './memory_store';

const app = createApp(new MemoryObjectStore(), {
  maxPayloadBytes: parseSize(
    process.env.MAX_PAYLOAD_BYTES,
    DEFAULT_MAX_PAYLOAD_BYTES,
  ),
});

const port = parseSize(process.env.PORT, 8787);

serve({ fetch: app.fetch, port });
