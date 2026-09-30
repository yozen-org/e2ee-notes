import {
  createApp,
  DEFAULT_MAX_PAYLOAD_BYTES,
  DEFAULT_TTL_SECONDS,
  parseSize,
} from './app';
import { CloudflareKvStore } from './kv_store';

export interface Env {
  TRANSFERS: KVNamespace;
  MAX_PAYLOAD_BYTES?: string;
  TTL_SECONDS?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const app = createApp(new CloudflareKvStore(env.TRANSFERS), {
      maxPayloadBytes: parseSize(
        env.MAX_PAYLOAD_BYTES,
        DEFAULT_MAX_PAYLOAD_BYTES,
      ),
      ttlSeconds: parseSize(env.TTL_SECONDS, DEFAULT_TTL_SECONDS),
    });
    return app.fetch(request, env);
  },
};
