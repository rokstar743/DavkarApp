import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/etoro_transaction.dart';

class XlsxParser {
  static Future<EtoroReport> parseXlsx(String xlsxPath) async {
    // Poišči converter.exe ob aplikaciji
    final converterPath = await _findConverter();

    // Temp mapa za CSV output
    final tempDir = await getTemporaryDirectory();
    final outputDir = Directory('${tempDir.path}/etoro_csv_${DateTime.now().millisecondsSinceEpoch}');
    await outputDir.create();

    try {
      // Pokliči converter
      final result = await Process.run(
        converterPath,
        [xlsxPath, outputDir.path],
      );

      if (result.exitCode != 0) {
        throw Exception('Converter ni uspel. Preverite ali je converter.exe v isti mapi kot aplikacija.');
      }

      // Preberi CSV-je
      final cpFile = File('${outputDir.path}/closed_positions.csv');
      final divFile = File('${outputDir.path}/dividends.csv');
      final aaFile = File('${outputDir.path}/account_activity.csv');

      if (!await cpFile.exists()) {
        throw Exception('Converter ni ustvaril closed_positions.csv.');
      }

      final closedPositions = _parseClosedPositions(_readCsv(await cpFile.readAsString()));
      final dividends = await divFile.exists()
          ? _parseDividends(_readCsv(await divFile.readAsString()))
          : <DividendRecord>[];
      final stockSplits = await aaFile.exists()
          ? _parseStockSplits(_readCsv(await aaFile.readAsString()))
          : <StockSplit>[];

      return EtoroReport(
        closedPositions: closedPositions,
        dividends: dividends,
        stockSplits: stockSplits,
      );
    } finally {
      // Počisti temp
      try { await outputDir.delete(recursive: true); } catch (_) {}
    }
  }

  static Future<String> _findConverter() async {
    // 1. Ob exe aplikacije
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final nextToExe = File('$exeDir/converter.exe');
    if (await nextToExe.exists()) return nextToExe.path;

    // 2. V trenutni mapi
    final inCurrent = File('converter.exe');
    if (await inCurrent.exists()) return inCurrent.path;

    throw Exception(
      'converter.exe ni najden.\n'
      'Kopirajte converter.exe v isto mapo kot davkarapp.exe'
    );
  }

  static List<List<String>> _readCsv(String content) {
    final lines = const LineSplitter().convert(content);
    return lines.where((l) => l.trim().isNotEmpty).map(_parseCsvLine).toList();
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(current.toString().trim());
        current.clear();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString().trim());
    return result;
  }

  static List<ClosedPosition> _parseClosedPositions(List<List<String>> rows) {
    if (rows.isEmpty) return [];
    final headers = _buildHeaders(rows[0]);
    final result = <ClosedPosition>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty || _col(row, headers, 'Position ID').isEmpty) continue;
      try {
        final type = _parseInstrumentType(_col(row, headers, 'Type'));
        final dirStr = _col(row, headers, 'Long / Short');
        final direction = dirStr.trim().toLowerCase() == 'short'
            ? PositionDirection.short
            : PositionDirection.long;
        final openDate = _parseDate(_col(row, headers, 'Open Date'));
        final closeDate = _parseDate(_col(row, headers, 'Close Date'));
        if (openDate == null || closeDate == null) continue;
        result.add(ClosedPosition(
          positionId: _col(row, headers, 'Position ID'),
          action: _col(row, headers, 'Action'),
          type: type,
          direction: direction,
          amount: _d(_col(row, headers, 'Amount')),
          units: _d(_col(row, headers, 'Units / Contracts')),
          openDate: openDate,
          closeDate: closeDate,
          leverage: int.tryParse(_col(row, headers, 'Leverage')) ?? 1,
          spreadFeesUsd: _d(_col(row, headers, 'Spread Fees (USD)')),
          profitUsd: _d(_col(row, headers, 'Profit(USD)')),
          profitEur: _d(_col(row, headers, 'Profit(EUR)')),
          openRateUsd: _d(_col(row, headers, 'Open Rate')),
          closeRateUsd: _d(_col(row, headers, 'Close Rate')),
          overnightFees: _d(_col(row, headers, 'Overnight Fees and Dividends')),
          isin: _col(row, headers, 'ISIN'),
        ));
      } catch (_) { continue; }
    }
    return result;
  }

  static List<DividendRecord> _parseDividends(List<List<String>> rows) {
    if (rows.isEmpty) return [];
    final headers = _buildHeaders(rows[0]);
    final result = <DividendRecord>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;
      try {
        final date = _parseDate(_col(row, headers, 'Date of Payment'));
        if (date == null) continue;
        final taxRateRaw = _col(row, headers, 'Withholding Tax Rate (%)');
        final taxRate = _d(taxRateRaw.replaceAll('%', '').trim());
        result.add(DividendRecord(
          date: date,
          instrumentName: _col(row, headers, 'Instrument Name'),
          isin: _col(row, headers, 'ISIN'),
          netDividendUsd: _d(_col(row, headers, 'Net Dividend Received (USD)')),
          netDividendEur: _d(_col(row, headers, 'Net Dividend Received (EUR)')),
          withholdingTaxRatePct: taxRate,
          withholdingTaxUsd: _d(_col(row, headers, 'Withholding Tax Amount (USD)')).abs(),
          positionId: _col(row, headers, 'Position ID'),
        ));
      } catch (_) { continue; }
    }
    return result;
  }

  static List<StockSplit> _parseStockSplits(List<List<String>> rows) {
    if (rows.isEmpty) return [];
    final headers = _buildHeaders(rows[0]);
    final result = <StockSplit>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;
      try {
        final type = _col(row, headers, 'Type');
        final details = _col(row, headers, 'Details');
        if (!type.toLowerCase().contains('split') &&
            !details.toLowerCase().contains('split')) continue;
        final date = _parseDate(_col(row, headers, 'Date'));
        if (date == null) continue;
        result.add(StockSplit(
          date: date,
          instrumentName: _col(row, headers, 'Asset type'),
          notes: details.isNotEmpty ? details : type,
        ));
      } catch (_) { continue; }
    }
    return result;
  }

  static Map<String, int> _buildHeaders(List<String> row) {
    final map = <String, int>{};
    for (int i = 0; i < row.length; i++) {
      if (row[i].isNotEmpty) map[row[i]] = i;
    }
    return map;
  }

  static String _col(List<String> row, Map<String, int> headers, String name) {
    final idx = headers[name];
    if (idx == null || idx >= row.length) return '';
    return row[idx];
  }

  static double _d(String raw) {
    if (raw.isEmpty || raw == '-') return 0.0;
    return double.tryParse(raw.replaceAll(',', '').replaceAll(' ', '')) ?? 0.0;
  }

  static InstrumentType _parseInstrumentType(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'stocks': return InstrumentType.stocks;
      case 'cfd': return InstrumentType.cfd;
      case 'crypto': return InstrumentType.crypto;
      default: return InstrumentType.unknown;
    }
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty || raw == '-') return null;
    try {
      final parts = raw.split(' ');
      final dp = parts[0].split('/');
      if (dp.length != 3) return null;
      int h = 0, m = 0, s = 0;
      if (parts.length > 1) {
        final tp = parts[1].split(':');
        if (tp.length == 3) {
          h = int.parse(tp[0]);
          m = int.parse(tp[1]);
          s = int.parse(tp[2]);
        }
      }
      return DateTime(int.parse(dp[2]), int.parse(dp[1]), int.parse(dp[0]), h, m, s);
    } catch (_) { return null; }
  }
}