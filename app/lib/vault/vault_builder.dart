import 'package:flutter/widgets.dart';

import '../notes/encrypted_notes_repository.dart';

typedef VaultBuilder = Widget Function(
  BuildContext context,
  EncryptedNotesRepository repository,
);
