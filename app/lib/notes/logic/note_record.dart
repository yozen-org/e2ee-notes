final class NoteRecord {
  const NoteRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.modifiedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime modifiedAt;
}
