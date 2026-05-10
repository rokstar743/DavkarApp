/// Vrsta instrumenta iz eToro
enum InstrumentType { stocks, cfd, crypto, unknown }

/// Smer pozicije
enum PositionDirection { long, short }

/// Surova zaprta pozicija iz eToro "Closed Positions" sheeta
class ClosedPosition {
  final String positionId;
  final String action; // ime instrumenta
  final InstrumentType type;
  final PositionDirection direction;
  final double amount; // investiran znesek USD
  final double units; // količina enot/kontraktov
  final DateTime openDate;
  final DateTime closeDate;
  final int leverage;
  final double spreadFeesUsd;
  final double profitUsd;
  final double profitEur;
  final double openRateUsd; // cena ob odprtju (USD na enoto)
  final double closeRateUsd; // cena ob zaprtju (USD na enoto)
  final double overnightFees;
  final String isin;

  const ClosedPosition({
    required this.positionId,
    required this.action,
    required this.type,
    required this.direction,
    required this.amount,
    required this.units,
    required this.openDate,
    required this.closeDate,
    required this.leverage,
    required this.spreadFeesUsd,
    required this.profitUsd,
    required this.profitEur,
    required this.openRateUsd,
    required this.closeRateUsd,
    required this.overnightFees,
    required this.isin,
  });

  @override
  String toString() =>
      'ClosedPosition($positionId, $action, $type, $direction, units=$units, '
      'open=$openDate, close=$closeDate)';
}

/// Dividenda iz eToro "Dividends" sheeta
class DividendRecord {
  final DateTime date;
  final String instrumentName;
  final String isin;
  final double netDividendUsd;
  final double netDividendEur;
  final double withholdingTaxRatePct; // npr. 15.0 za 15%
  final double withholdingTaxUsd;
  final String positionId;

  const DividendRecord({
    required this.date,
    required this.instrumentName,
    required this.isin,
    required this.netDividendUsd,
    required this.netDividendEur,
    required this.withholdingTaxRatePct,
    required this.withholdingTaxUsd,
    required this.positionId,
  });

  @override
  String toString() =>
      'Dividend($instrumentName, $date, net=$netDividendEur EUR)';
}

/// Stock split korporativna akcija iz "Account Activity" sheeta
class StockSplit {
  final DateTime date;
  final String instrumentName;
  final String notes; // npr. "NVDA 1:10 split"

  const StockSplit({
    required this.date,
    required this.instrumentName,
    required this.notes,
  });
}

/// Celotno poročilo iz eToro xlsx
class EtoroReport {
  final List<ClosedPosition> closedPositions;
  final List<DividendRecord> dividends;
  final List<StockSplit> stockSplits;

  const EtoroReport({
    required this.closedPositions,
    required this.dividends,
    required this.stockSplits,
  });

  /// Filtriraj samo pozicije za izbrano leto
  EtoroReport forYear(int year) {
    return EtoroReport(
      closedPositions: closedPositions
          .where((p) => p.closeDate.year == year)
          .toList(),
      dividends: dividends
          .where((d) => d.date.year == year)
          .toList(),
      stockSplits: stockSplits
          .where((s) => s.date.year == year)
          .toList(),
    );
  }

  /// Vsa leta v poročilu (za dropdown izbiro)
  List<int> get availableYears {
    final years = <int>{};
    for (final p in closedPositions) {
      years.add(p.closeDate.year);
    }
    for (final d in dividends) {
      years.add(d.date.year);
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }
}