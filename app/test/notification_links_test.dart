import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/utils/notification_links.dart';

void main() {
  group('notificationLinkAllowedForRole', () {
    test('allows the shared inbox for every authenticated role', () {
      expect(
        notificationLinkAllowedForRole('/student/notifications',
            isStudent: false),
        isTrue,
      );
      expect(
        notificationLinkAllowedForRole('studybirds://student/notifications',
            isStudent: false),
        isTrue,
      );
    });

    test('keeps student workflow links exclusive to student accounts', () {
      expect(
        notificationLinkAllowedForRole('/student/applications',
            isStudent: false),
        isFalse,
      );
      expect(
        notificationLinkAllowedForRole('/student/applications',
            isStudent: true),
        isTrue,
      );
    });

    test('rejects malformed, external and unrelated links', () {
      expect(notificationLinkAllowedForRole(null, isStudent: true), isFalse);
      expect(notificationLinkAllowedForRole('', isStudent: true), isFalse);
      expect(
        notificationLinkAllowedForRole(
            'https://example.com/student/notifications',
            isStudent: false),
        isFalse,
      );
      expect(
        notificationLinkAllowedForRole('/admin/users', isStudent: false),
        isFalse,
      );
    });
  });
}
