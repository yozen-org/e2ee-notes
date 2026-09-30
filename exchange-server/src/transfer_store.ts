export interface TransferStore {
  put(token: string, payload: string, ttlSeconds: number): Promise<void>;
  consume(token: string): Promise<string | null>;
}
