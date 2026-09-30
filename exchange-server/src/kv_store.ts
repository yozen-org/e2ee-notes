import type { ObjectStore } from './object_store';

export class CloudflareKvObjectStore implements ObjectStore {
  constructor(private readonly kv: KVNamespace) {}

  async put(key: string, value: ArrayBuffer): Promise<void> {
    if ((await this.kv.get(key)) === null) {
      await this.kv.put(key, value);
    }
  }

  async get(key: string): Promise<ArrayBuffer | null> {
    return this.kv.get(key, 'arrayBuffer');
  }

  async list(prefix: string): Promise<string[]> {
    const keys: string[] = [];
    let cursor: string | undefined;
    do {
      const result = await this.kv.list({ prefix, cursor });
      keys.push(...result.keys.map((entry) => entry.name));
      cursor = result.list_complete ? undefined : result.cursor;
    } while (cursor !== undefined);
    return keys;
  }

  async delete(key: string): Promise<boolean> {
    const existing = await this.kv.get(key);
    if (existing === null) return false;
    await this.kv.delete(key);
    return true;
  }
}
