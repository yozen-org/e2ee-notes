import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The filesystem directory that holds this device's vault.
Future<Directory> vaultRoot() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'e2ee-notes'));
}
