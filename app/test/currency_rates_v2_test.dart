import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_birds/core/services/currency_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('SAR and USD use complete validated v2 rates with identity rates',
      () async {
    await http.runWithClient(() async {
      for (final base in ['SAR', 'USD']) {
        final rates = await CurrencyService.instance.fetchRates(base);
        expect(rates[base], 1);
        expect(rates.keys.toSet(), supportedCurrencies.keys.toSet());
      }
    },
        () => MockClient((request) async {
              expect(request.url.host, 'api.frankfurter.dev');
              expect(request.url.path, '/v2/rates');
              final base = request.url.queryParameters['base'];
              return http.Response(
                  jsonEncode(supportedCurrencies.keys
                      .where((c) => c != base)
                      .map((c) => {
                            'base': base,
                            'quote': c,
                            'rate': c == 'SAR' ? 3.75 : 1.2,
                          })
                      .toList()),
                  200);
            }));
  });
  test('incomplete rates fail rather than inventing a one-to-one conversion',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          CurrencyService.instance.fetchRates('JOD'), throwsFormatException);
    }, () => MockClient((_) async => http.Response('[]', 200)));
  });
}
