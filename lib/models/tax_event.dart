/// En FIFO par: nakup → prodaja za Doh-KDVP
class StockTaxEvent {
  final String isin;
  final String name;
  final DateTime purchaseDate;
  final double purchaseRateEur; // nabavna vrednost na enoto v EUR (z +1% normiranimi stroški)
  final DateTime saleDate;
  final double saleRateEur; // vrednost ob odsvojitvi na enoto v EUR (z -1% normiranimi stroški)
  final double units;

  // BSI tečaji, ki so bili uporabljeni
  final double bsiRateAtPurchase;
  final double bsiRateAtSale;

  const StockTaxEvent({
    required this.isin,
    required this.name,
    required this.purchaseDate,
    required this.purchaseRateEur,
    required this.saleDate,
    required this.saleRateEur,
    required this.units,
    required this.bsiRateAtPurchase,
    required this.bsiRateAtSale,
  });

  double get totalPurchaseEur => units * purchaseRateEur;
  double get totalSaleEur => units * saleRateEur;
  double get profitEur => totalSaleEur - totalPurchaseEur;

  @override
  String toString() =>
      'StockTaxEvent($name, $units units, '
      'buy=$purchaseDate @ ${purchaseRateEur.toStringAsFixed(4)} EUR, '
      'sell=$saleDate @ ${saleRateEur.toStringAsFixed(4)} EUR, '
      'profit=${profitEur.toStringAsFixed(2)} EUR)';
}

/// CFD posel za D-IFI
class CfdTaxEvent {
  final String isin;
  final String name;
  final bool isLong;
  final double units;

  // Long pozicija: Purchase + Sale
  // Short pozicija: Sale + Purchase (obrnjeno)
  final DateTime openDate;
  final double openRateEur;
  final DateTime closeDate;
  final double closeRateEur;

  final double bsiRateAtOpen;
  final double bsiRateAtClose;

  final bool hasLeverage; // leverage > 1
  final double overnightFees; // overnight fees so del stroška

  const CfdTaxEvent({
    required this.isin,
    required this.name,
    required this.isLong,
    required this.units,
    required this.openDate,
    required this.openRateEur,
    required this.closeDate,
    required this.closeRateEur,
    required this.bsiRateAtOpen,
    required this.bsiRateAtClose,
    required this.hasLeverage,
    required this.overnightFees,
  });

  double get profitEur =>
      isLong
          ? (closeRateEur - openRateEur) * units
          : (openRateEur - closeRateEur) * units;

  @override
  String toString() =>
      'CfdTaxEvent($name, ${isLong ? "Long" : "Short"}, $units units, '
      'profit=${profitEur.toStringAsFixed(2)} EUR)';
}

/// Crypto pozicija — parsana ampak brez XML outputa
/// Pripravljena za bodočo zakonodajo
class CryptoTaxEvent {
  final String name;
  final double units;
  final DateTime openDate;
  final double openRateEur;
  final DateTime closeDate;
  final double closeRateEur;
  final double profitEur;

  const CryptoTaxEvent({
    required this.name,
    required this.units,
    required this.openDate,
    required this.openRateEur,
    required this.closeDate,
    required this.closeRateEur,
    required this.profitEur,
  });
}

/// Dividenda za Doh-Div
class DividendTaxEvent {
  final DateTime date;
  final String instrumentName;
  final String isin;
  final double netAmountEur;
  final double withholdingTaxEur; // že plačan tuji davek
  final double withholdingTaxRatePct;

  // eToro je izplačevalec (Cyprus)
  static const String payerName = 'eToro Europe Ltd.';
  static const String payerAddress = '4 Profiti Ilia Street, Germasogia, Limassol, Cyprus';
  static const String payerCountry = 'CY';

  const DividendTaxEvent({
    required this.date,
    required this.instrumentName,
    required this.isin,
    required this.netAmountEur,
    required this.withholdingTaxEur,
    required this.withholdingTaxRatePct,
  });

  /// Bruto = neto + zadržani davek
  double get grossAmountEur => netAmountEur + withholdingTaxEur;

  @override
  String toString() =>
      'DividendTaxEvent($instrumentName, $date, '
      'gross=${grossAmountEur.toStringAsFixed(2)} EUR, '
      'tax=${withholdingTaxEur.toStringAsFixed(2)} EUR)';
}

/// Celotno davčno poročilo za eno leto
class TaxReport {
  final int year;
  final List<StockTaxEvent> stocks;
  final List<CfdTaxEvent> cfds;
  final List<CryptoTaxEvent> cryptos; // parsano, ne exportano
  final List<DividendTaxEvent> dividends;

  const TaxReport({
    required this.year,
    required this.stocks,
    required this.cfds,
    required this.cryptos,
    required this.dividends,
  });

  double get totalStockProfitEur =>
      stocks.fold(0, (sum, e) => sum + e.profitEur);

  double get totalCfdProfitEur =>
      cfds.fold(0, (sum, e) => sum + e.profitEur);

  double get totalDividendEur =>
      dividends.fold(0, (sum, e) => sum + e.grossAmountEur);

  bool get hasStocks => stocks.isNotEmpty;
  bool get hasCfds => cfds.isNotEmpty;
  bool get hasDividends => dividends.isNotEmpty;
}