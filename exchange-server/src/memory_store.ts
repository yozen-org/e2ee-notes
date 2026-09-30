import type { TransferStore } from './transfer_store';

interface Entry {
  payload: string;
  expiresAt: number;
}

export class MemoryStore implements TransferStore {
  private readonly entries = new Map<string, Entry>();

  async put(token: string, payload: string, ttlSeconds: number): Promise<void> {
    this.entries.set(token, {
      payload,
      expiresAt: Date.now() + ttlSeconds * 1000,
    });
  }

  async consume(token: string): Promise<string | null> {
    const entry = this.entries.get(token);
    if (entry === undefined) return null;
    this.entries.delete(token);
    if (entry.expiresAt < Date.now()) return null;
    return entry.payload;
  }
}
