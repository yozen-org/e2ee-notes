final class KeyCapabilities {
  const KeyCapabilities({
    required this.hardwareBacked,
    required this.sharing,
    required this.userPresence,
  });
  final bool hardwareBacked;
  final bool sharing;
  final bool userPresence;
}
