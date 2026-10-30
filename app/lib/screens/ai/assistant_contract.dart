import 'assistant_navigation.dart';

/// An old backend must never silently accept new assistant UI requests.
abstract final class AssistantContract {
  static bool matchesProtocol(dynamic config) =>
      config is Map &&
      config['scopePolicy'] == 'studybirds-only-v1' &&
      config['responseFormat'] == 'verified-help-v1' &&
      config['knowledgeVersion'] == AssistantNavigation.knowledgeVersion;

  static bool acceptsResponse(dynamic config) => matchesProtocol(config);

  static bool accepts(dynamic config) =>
      config is Map && config['enabled'] == true && matchesProtocol(config);
}
