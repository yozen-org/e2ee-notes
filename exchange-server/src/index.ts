import { createApp, DEFAULT_MAX_PAYLOAD_BYTES, parseSize } from './app';
import { CloudflareKvObjectStore } from './kv_store';

export interface Env {
  OBJECTS: KVNamespace;
  MAX_PAYLOAD_BYTES?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const app = createApp(new CloudflareKvObjectStore(env.OBJECTS), {
      maxPayloadBytes: parseSize(env.MAX_PAYLOAD_BYTES, DEFAULT_MAX_PAYLOAD_BYTES),
    });
    return app.fetch(request, env);
  },
};
