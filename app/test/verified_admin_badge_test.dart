import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_birds/core/widgets/verified_admin_badge.dart';

void main() {
  testWidgets('official badge is derived from the backend role only',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Column(
        children: [
          VerifiedAdminBadge(role: 'admin'),
          VerifiedAdminBadge(role: 'student'),
          VerifiedAdminBadge(role: 'employee'),
        ],
      ),
    ));

    expect(find.byKey(const ValueKey('verified-admin-badge')), findsOneWidget);
    expect(find.bySemanticsLabel('Verified official COVEY administrator'),
        findsOneWidget);
  });
}
