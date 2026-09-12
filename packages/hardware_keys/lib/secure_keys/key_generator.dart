abstract interface class KeyGenerator<K extends Object> {
  Future<K> generate();
}
