import 'package:flutter_test/flutter_test.dart';
import 'package:study_birds/screens/ai/assistant_contract.dart';
import 'package:study_birds/screens/ai/assistant_navigation.dart';

void main() {
  test('accepts only an explicitly scoped, version-matched assistant backend',
      () {
    final good = {
      'enabled': true,
      'scopePolicy': 'studybirds-only-v1',
      'responseFormat': 'verified-help-v1',
      'knowledgeVersion': AssistantNavigation.knowledgeVersion
    };
    expect(AssistantContract.accepts(good), isTrue);
    expect(AssistantContract.acceptsResponse(good), isTrue);
    for (final bad in [
      <String, Object>{},
      {...good, 'scopePolicy': 'general-chat'},
      {...good, 'responseFormat': 'free-text'},
      {...good, 'knowledgeVersion': 'old'}
    ]) {
      expect(AssistantContract.accepts(bad), isFalse);
      expect(AssistantContract.acceptsResponse(bad), isFalse);
    }
    expect(AssistantContract.accepts({...good, 'enabled': false}), isFalse);
  });
}
