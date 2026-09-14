import 'package:flutter/material.dart';

import 'app.dart';
import 'vault/vault_bootstrap.dart';

void main() => runApp(E2eeNotesApp(repository: openLocalVault()));
