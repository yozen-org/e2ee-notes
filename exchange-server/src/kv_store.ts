import type { TransferStore } from './transfer_store';

export class CloudflareKvStore implements TransferStore {
  constructor(private readonly kv: KVNamespace) {}

  async put(token: string, payload: string, ttlSeconds: number): Promise<void> {
    await this.kv.put(token, payload, { expirationTtl: ttlSeconds });
  }

  async consume(token: string): Promise<string | null> {
    const payload = await this.kv.get(token);
    if (payload === null) return null;
    await this.kv.delete(token);
    return payload;
  }
}
