import '../utils/json_safe.dart';
import 'error_reporter.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const supportedCurrencies = {
  'USD': 'الدولار الأمريكي',
  'EUR': 'اليورو',
  'GBP': 'الجنيه الإسترليني',
  'TRY': 'الليرة التركية',
  'AED': 'الدرهم الإماراتي',
  'EGP': 'الجنيه المصري',
  'SAR': 'الريال السعودي',
  'JOD': 'الدينار الأردني',
};

/// Approximate rates from USD (used as offline fallback only).
const _fallbackRatesFromUsd = {
  'USD': 1.0,
  'EUR': 0.92,
  'GBP': 0.79,
  'TRY': 32.5,
  'AED': 3.67,
  'EGP': 48.0,
  'SAR': 3.75,
  'JOD': 0.71,
};

const _prefKeySelectedCurrency = 'selected_display_currency';

class _CurrencyNotifier extends ValueNotifier<String> {
  _CurrencyNotifier() : super('USD');
  void refresh() => notifyListeners();
}

class CurrencyService {
  CurrencyService._();
  static final instance = CurrencyService._();

  String _selected = 'USD';
  String get selected => _selected;

  final notifier = _CurrencyNotifier();
  DateTime? ratesUpdatedAt;
  final _rateInflight = <String, Future<Map<String, double>>>{};

  /// Rates from USD to every supported currency. Populated by [fetchRatesFromUsd].
  Map<String, double> _ratesFromUsd = Map.of(_fallbackRatesFromUsd);
  Map<String, double> get ratesFromUsd => _ratesFromUsd;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _selected = prefs.getString(_prefKeySelectedCurrency) ?? 'USD';
    notifier.value = _selected;
    final saved = _savedRates(prefs, 'USD');
    if (saved != null) _ratesFromUsd = saved;
  }

  Future<void> select(String currency) async {
    _selected = currency;
    notifier.value = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySelectedCurrency, currency);
  }

  /// Converts a USD amount to the currently selected display currency.
  double convertFromUsd(double usdAmount) {
    return usdAmount * (_ratesFromUsd[_selected] ?? 1.0);
  }

  String formatAmount(num? usdAmount) {
    final val = convertFromUsd((usdAmount ?? 0).toDouble());
    final symbol = _currencySymbol(_selected);
    if (val >= 1000) {
      return '$symbol${val.toStringAsFixed(0)}';
    }
    return '$symbol${val.toStringAsFixed(val < 10 ? 2 : 1)}';
  }

  static String _currencySymbol(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'TRY':
        return '₺';
      case 'AED':
        return 'د.إ ';
      case 'EGP':
        return 'ج.م ';
      case 'SAR':
        return 'ر.س ';
      case 'JOD':
        return 'د.أ ';
      default:
        return '$code ';
    }
  }

  /// Fetches live rates from frankfurter.app (base = any currency).
  /// Also refreshes [_ratesFromUsd] when base is USD.
  Map<String, double>? _savedRates(SharedPreferences prefs, String base) {
    try {
      final raw = prefs.getString('exchange_rates_v2:$base');
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.parse(j['at'] as String);
      final age = DateTime.now().difference(at);
      if (age.isNegative || age >= const Duration(hours: 24)) return null;
      ratesUpdatedAt = at;
      return (j['rates'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>> fetchRates(String base) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _savedRates(prefs, base);
    if (saved != null) {
      if (base == 'USD') _ratesFromUsd = saved;
      if (DateTime.now().difference(ratesUpdatedAt!) >=
          const Duration(hours: 6)) {
        _networkRates(base).catchError((Object _, StackTrace __) => saved);
      }
      return saved;
    }
    return _networkRates(base);
  }

  Future<Map<String, double>> _networkRates(String base) {
    final pending = _rateInflight[base];
    if (pending != null) return pending;
    final future = _downloadRates(base);
    _rateInflight[base] = future;
    return future.whenComplete(() {
      _rateInflight.remove(base);
    });
  }

  Future<Map<String, double>> _downloadRates(String base) async {
    final others = supportedCurrencies.keys.where((c) => c != base).join(',');
    final uri =
        Uri.parse('https://api.frankfurter.app/latest?from=$base&to=$others');
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) throw Exception('Failed to fetch rates');
    final body = Json.rawMap(jsonDecode(resp.body));
    final rates = Map<String, double>.from((Json.rawMap(body['rates']))
        .map((k, v) => MapEntry(k as String, (v as num).toDouble())));
    rates[base] = 1.0;
    if (rates.values.any((v) => !v.isFinite || v <= 0)) {
      throw const FormatException('Invalid exchange rates');
    }
    if (base == 'USD') _ratesFromUsd = rates;
    ratesUpdatedAt = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'exchange_rates_v2:$base',
          jsonEncode({
            'at': ratesUpdatedAt!.toUtc().toIso8601String(),
            'rates': rates
          }));
    } catch (_) {
      /* Live results still work if device storage is unavailable. */
    }
    notifier.refresh();
    return rates;
  }

  /// Silently refreshes USD rates in the background. Safe to call on screen init.
  void refreshRatesInBackground() {
    fetchRates('USD').catchError(ErrorReporter.fallback(
        'core/services/currency_service.dart:102', _ratesFromUsd));
  }
}
