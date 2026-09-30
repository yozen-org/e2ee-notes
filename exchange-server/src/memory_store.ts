import type { ObjectStore } from './object_store';

export class MemoryObjectStore implements ObjectStore {
  private readonly objects = new Map<string, ArrayBuffer>();

  async put(key: string, value: ArrayBuffer): Promise<void> {
    if (!this.objects.has(key)) {
      this.objects.set(key, value);
    }
  }

  async get(key: string): Promise<ArrayBuffer | null> {
    return this.objects.get(key) ?? null;
  }

  async list(prefix: string): Promise<string[]> {
    return [...this.objects.keys()]
      .filter((key) => key.startsWith(prefix))
      .sort();
  }

  async delete(key: string): Promise<boolean> {
    return this.objects.delete(key);
  }
}
