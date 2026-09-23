import 'encrypted_notes_repository.dart';

sealed class NotesState {
  const NotesState();
}

final class NotesLoading extends NotesState {
  const NotesLoading();
}

final class NotesFailed extends NotesState {
  const NotesFailed(this.error);

  final Object error;
}

final class NotesReady extends NotesState {
  const NotesReady(this.notes);

  final List<NoteRecord> notes;
}
