/// Application policy; permission to use software storage is never inferred.
final class KeyPolicy {
  const KeyPolicy({
    this.allowSoftware = false,
    this.requireUserPresence = false,
  });
  final bool allowSoftware;
  final bool requireUserPresence;
}
