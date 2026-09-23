import 'notes/encrypted_notes_repository.dart';

sealed class HomeState {
  const HomeState();
}

final class HomeLoading extends HomeState {
  const HomeLoading();
}

final class HomeFailed extends HomeState {
  const HomeFailed(this.error);

  final Object error;
}

final class HomeReady extends HomeState {
  const HomeReady(this.repository);

  final EncryptedNotesRepository repository;
}
