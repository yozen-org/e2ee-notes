export interface ObjectStore {
  put(key: string, value: ArrayBuffer): Promise<void>;
  get(key: string): Promise<ArrayBuffer | null>;
  list(prefix: string): Promise<string[]>;
  delete(key: string): Promise<boolean>;
}
