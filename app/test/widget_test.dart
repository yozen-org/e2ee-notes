import 'dart:typed_data';

import 'package:e2ee_notes/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_repository/notes_repository.dart';
import 'package:storage_api/storage_api.dart';

final class MemoryStore implements BlobStore {
  final objects = <String, Uint8List>{};

  @override
  Future<void> delete(String key) async => objects.remove(key);

  @override
  Future<Uint8List> get(String key) async => objects[key]!;

  @override
  Future<List<String>> list(String prefix) async =>
      objects.keys.where((key) => key.startsWith(prefix)).toList();

  @override
  Future<void> putIfAbsent(String key, Uint8List value) async {
    objects[key] = value;
  }
}

void main() {
  testWidgets('creates and displays an encrypted note', (tester) async {
    final store = MemoryStore();
    final repository = EncryptedNotesRepository(
      store: store,
      vaultKey: Uint8List(32),
      deviceId: 'a' * 64,
    );
    await tester.pumpWidget(E2eeNotesApp(repository: Future.value(repository)));
    await tester.pumpAndSettle();

    expect(find.text('Your notes, your keys, your storage.'), findsOneWidget);
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'My note');
    await tester.enterText(find.byType(TextFormField).last, 'Private body');
    await tester.tap(find.text('Encrypt & save'));
    await tester.pumpAndSettle();

    expect(find.text('My note'), findsOneWidget);
    expect(find.text('Private body'), findsOneWidget);
    expect(store.objects, hasLength(1));
  });
}
