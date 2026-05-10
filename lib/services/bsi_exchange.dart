import 'package:http/http.dart' as http;

/// Pridobi USD/EUR tečaje iz ECB API
/// ECB objavlja EUR/USD (koliko USD za 1 EUR)
/// Mi potrebujemo USD→EUR = 1 / (EUR/USD tečaj)
class BsiExchangeService {
  // ECB Data Portal API - javno dostopen, brez avtentikacije
  static const String _ecbUrl =
      'https://data-api.ecb.europa.eu/service/data/EXR/D.USD.EUR.SP00.A';

  final Map<String, double> _cache = {};

  /// Vrne USD→EUR tečaj za datum (ali najbližji delovni dan prej)
  Future<double> getUsdToEurRate(DateTime date) async {
    final key = _fmt(date);
    if (_cache.containsKey(key)) return _cache[key]!;

    // Poskusi z do 7 dnevi nazaj (vikendi, prazniki)
    for (int offset = 0; offset <= 7; offset++) {
      final d = date.subtract(Duration(days: offset));
      final rate = await _fetchEcbRate(d);
      if (rate != null) {
        // Shrani v cache za vse vmesne datume
        for (int i = 0; i <= offset; i++) {
          final dk = _fmt(date.subtract(Duration(days: i)));
          _cache[dk] = rate;
        }
        return rate;
      }
    }

    throw Exception('Tečaj ni na voljo za datum ${_fmt(date)} (USD)');
  }

  /// Prefetch za celo leto naenkrat — ena HTTP zahteva
  Future<void> prefetchForYear(int year, Set<String> currencies) async {
    if (!currencies.contains('USD')) return;
    await _fetchEcbRange(
      DateTime(year, 1, 1),
      DateTime(year, 12, 31),
    );
  }

  Future<void> _fetchEcbRange(DateTime start, DateTime end) async {
    try {
      final uri = Uri.parse(_ecbUrl).replace(queryParameters: {
        'startPeriod': _fmt(start),
        'endPeriod': _fmt(end),
        'format': 'csvdata',
      });

      final resp = await http.get(uri, headers: {
        'Accept': 'text/csv',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) return;

      // Parse CSV — format: KEY,FREQ,CURRENCY,CURRENCY_DENOM,...,TIME_PERIOD,OBS_VALUE
      final lines = resp.body.split('\n');
      if (lines.length < 2) return;

      // Najdi indekse stolpcev iz headerja
      final headers = lines[0].split(',');
      final timeIdx = headers.indexOf('TIME_PERIOD');
      final valIdx = headers.indexOf('OBS_VALUE');
      if (timeIdx < 0 || valIdx < 0) return;

      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length <= valIdx) continue;
        final dateStr = parts[timeIdx].trim();
        final valStr = parts[valIdx].trim();
        if (dateStr.isEmpty || valStr.isEmpty) continue;
        final eurUsd = double.tryParse(valStr);
        if (eurUsd == null || eurUsd == 0) continue;
        // ECB daje EUR/USD → mi rabimo USD/EUR = 1/eurUsd
        _cache[dateStr] = 1.0 / eurUsd;
      }
    } catch (_) {}
  }

  Future<double?> _fetchEcbRate(DateTime date) async {
    final dateStr = _fmt(date);
    if (_cache.containsKey(dateStr)) return _cache[dateStr];

    try {
      final uri = Uri.parse(_ecbUrl).replace(queryParameters: {
        'startPeriod': dateStr,
        'endPeriod': dateStr,
        'format': 'csvdata',
      });

      final resp = await http.get(uri, headers: {
        'Accept': 'text/csv',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return null;

      final lines = resp.body.split('\n');
      if (lines.length < 2) return null;

      final headers = lines[0].split(',');
      final timeIdx = headers.indexOf('TIME_PERIOD');
      final valIdx = headers.indexOf('OBS_VALUE');
      if (timeIdx < 0 || valIdx < 0) return null;

      for (int i = 1; i < lines.length; i++) {
        final parts = lines[i].split(',');
        if (parts.length <= valIdx) continue;
        final valStr = parts[valIdx].trim();
        if (valStr.isEmpty) continue;
        final eurUsd = double.tryParse(valStr);
        if (eurUsd == null || eurUsd == 0) continue;
        final rate = 1.0 / eurUsd;
        _cache[dateStr] = rate;
        return rate;
      }
    } catch (_) {}

    return null;
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}