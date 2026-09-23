import 'package:e2ee_notes/l10n/app_localizations.dart';
import 'package:e2ee_notes/vault/key_policy/key_policy_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_keys/secure_keys.dart';

void main() {
  for (final hardwareBacked in [false, true]) {
    testWidgets('returns accepted policy: $hardwareBacked', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (current) {
              context = current;
              return const SizedBox();
            },
          ),
        ),
      );

      final policy = showKeyPolicyDialog(
        context,
        KeyCapabilities(
          hardwareBacked: hardwareBacked,
          sharing: hardwareBacked,
          userPresence: hardwareBacked,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect((await policy).allowSoftware, !hardwareBacked);
    });
  }

  testWidgets('reports cancellation', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (current) {
            context = current;
            return const SizedBox();
          },
        ),
      ),
    );

    final policy = showKeyPolicyDialog(
      context,
      const KeyCapabilities(
        hardwareBacked: true,
        sharing: true,
        userPresence: true,
      ),
    );
    final cancellation = expectLater(policy, throwsStateError);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await cancellation;
  });
}
