import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/core/services/auth_session.dart';

void main() {
  const account = {'_id': 'google-user', 'role': 'student', 'email': 'user@gmail.com'};

  test('Google responses without password status require password setup', () {
    final user = AuthUser.fromGoogleJson(account);
    expect(user.hasPassword, isFalse);
    expect(user.authProvider, 'google');
    expect(AuthUser.fromJson(user.toJson()).hasPassword, isFalse);
  });

  test('Google linked local account with unknown status requires setup', () {
    expect(AuthUser.fromGoogleJson({...account, 'authProvider': 'local'}).hasPassword,
        isFalse);
  });

  test('Only an explicit existing password allows Google to skip setup', () {
    expect(AuthUser.fromGoogleJson({...account, 'hasPassword': false}).hasPassword,
        isFalse);
    expect(AuthUser.fromGoogleJson({...account, 'hasPassword': true}).hasPassword,
        isTrue);
  });
}
