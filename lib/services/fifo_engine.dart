import 'package:collection/collection.dart';
import '../models/etoro_transaction.dart';
import '../models/tax_event.dart';
import 'bsi_exchange.dart';

/// FIFO procesor — pretvori zaprte pozicije v davčne dogodke
///
/// Normativni stroški po ZDoh-2:
///   nabavna vrednost = cena * 1.01  (+1%)
///   prodajna vrednost = cena * 0.99 (-1%)
class FifoEngine {
  static const double _normCostFactor = 0.01; // 1%

  final BsiExchangeService _bsi;

  FifoEngine(this._bsi);

  /// Procesira celoten EtoroReport za dano leto
  /// Vrne TaxReport z vsemi davčnimi dogodki
  Future<TaxReport> process(EtoroReport report, int year) async {
    // Batch prefetch BSI tečajev za celo leto (optimizacija)
    await _bsi.prefetchForYear(year, {'USD'});

    // Zberi vse pozicije (vsa leta!) za FIFO — prodaje filtriramo po letu
    final allPositions = report.closedPositions;

    final stocks = await _processStocks(allPositions, year);
    final cfds = await _processCfds(allPositions, year);
    final cryptos = await _processCryptos(allPositions, year);
    final dividends = await _processDividends(report.dividends, year);

    return TaxReport(
      year: year,
      stocks: stocks,
      cfds: cfds,
      cryptos: cryptos,
      dividends: dividends,
    );
  }

  // ---------------------------------------------------------------------------
  // Stocks — FIFO
  // ---------------------------------------------------------------------------

  Future<List<StockTaxEvent>> _processStocks(
      List<ClosedPosition> allPositions, int year) async {
    // Filtriraj samo Stocks
    final stockPositions = allPositions
        .where((p) => p.type == InstrumentType.stocks)
        .toList()
      ..sort((a, b) => a.openDate.compareTo(b.openDate));

    // Grupiraj po ISIN
    final byIsin = groupBy(stockPositions, (p) => p.isin);

    final result = <StockTaxEvent>[];

    for (final entry in byIsin.entries) {
      final isin = entry.key;
      final positions = entry.value
        ..sort((a, b) => a.openDate.compareTo(b.openDate));

      // FIFO queue: vsak nakup je (datum, cena_eur_na_enoto, preostale_enote)
      final queue = <_FifoLot>[];

      for (final pos in positions) {
        if (pos.direction == PositionDirection.long) {
          // Nakup — dodaj v FIFO vrsto
          final bsiRate = await _bsi.getUsdToEurRate(pos.openDate);
          // Nabavna cena v EUR + 1% normativni stroški
          final purchasePriceEur =
              pos.openRateUsd * bsiRate * (1 + _normCostFactor);

          queue.add(_FifoLot(
            date: pos.openDate,
            priceEur: purchasePriceEur,
            units: pos.units,
            bsiRate: bsiRate,
            instrumentName: pos.action,
          ));
        } else {
          // Short stocks — na eToru dejanskih short stock pozicij ni,
          // to bi bili CFD-ji. Preskoči.
          continue;
        }
      }

      // Zdaj procesiraj prodaje (samo tiste v izbranem letu)
      final salesThisYear = positions
          .where((p) =>
              p.direction == PositionDirection.long &&
              p.closeDate.year == year)
          .toList()
        ..sort((a, b) => a.closeDate.compareTo(b.closeDate));

      // Rebuild queue z vsemi nakupi, potem simuliraj prodaje v FIFO
      // Rebuild: vzemi vse nakupe v kronološkem redu
      final fifoQueue = <_FifoLot>[];
      for (final pos in positions.where(
          (p) => p.direction == PositionDirection.long)) {
        final bsiRate = await _bsi.getUsdToEurRate(pos.openDate);
        final purchasePriceEur =
            pos.openRateUsd * bsiRate * (1 + _normCostFactor);
        fifoQueue.add(_FifoLot(
          date: pos.openDate,
          priceEur: purchasePriceEur,
          units: pos.units,
          bsiRate: bsiRate,
          instrumentName: pos.action,
        ));
      }

      // Procesiraj vsako prodajo z FIFO
      for (final sale in salesThisYear) {
        final bsiRateAtSale = await _bsi.getUsdToEurRate(sale.closeDate);
        // Prodajna cena v EUR - 1% normativni stroški
        final salePriceEur =
            sale.closeRateUsd * bsiRateAtSale * (1 - _normCostFactor);

        double remainingToSell = sale.units;

        while (remainingToSell > 0 && fifoQueue.isNotEmpty) {
          final lot = fifoQueue.first;

          final soldFromLot =
              remainingToSell <= lot.units ? remainingToSell : lot.units;

          result.add(StockTaxEvent(
            isin: isin,
            name: lot.instrumentName,
            purchaseDate: lot.date,
            purchaseRateEur: lot.priceEur,
            saleDate: sale.closeDate,
            saleRateEur: salePriceEur,
            units: soldFromLot,
            bsiRateAtPurchase: lot.bsiRate,
            bsiRateAtSale: bsiRateAtSale,
          ));

          remainingToSell -= soldFromLot;
          lot.units -= soldFromLot;

          if (lot.units <= 0.000001) {
            fifoQueue.removeAt(0);
          }
        }

        if (remainingToSell > 0.000001) {
          // Prodanih je več kot kupljenih — podatki so nepopolni
          // To se zgodi če je account starejši od izvoza
          throw Exception(
            'FIFO napaka za $isin: prodanih ${sale.units} enot, '
            'ampak v FIFO vrsti ni dovolj nakupov. '
            'Preverite, ali ste izvozili celotno zgodovino računa.',
          );
        }
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // CFD
  // ---------------------------------------------------------------------------

  Future<List<CfdTaxEvent>> _processCfds(
      List<ClosedPosition> allPositions, int year) async {
    final cfds = allPositions
        .where((p) =>
            p.type == InstrumentType.cfd && p.closeDate.year == year)
        .toList();

    final result = <CfdTaxEvent>[];

    for (final pos in cfds) {
      // CFD-ji imajo openRateUsd in closeRateUsd v valuti instrumenta
      // Če je '-', pomeni da je cena v USD in je direktno profitUsd
      final bsiOpen = await _bsi.getUsdToEurRate(pos.openDate);
      final bsiClose = await _bsi.getUsdToEurRate(pos.closeDate);

      double openEur;
      double closeEur;

      if (pos.openRateUsd > 0 && pos.closeRateUsd > 0) {
        openEur = pos.openRateUsd * bsiOpen;
        closeEur = pos.closeRateUsd * bsiClose;
      } else {
        // Fallback: izračunaj iz amount in profit
        openEur = pos.amount * bsiOpen;
        closeEur = (pos.amount + pos.profitUsd) * bsiClose;
      }

      result.add(CfdTaxEvent(
        isin: pos.isin,
        name: pos.action,
        isLong: pos.direction == PositionDirection.long,
        units: pos.units,
        openDate: pos.openDate,
        openRateEur: openEur,
        closeDate: pos.closeDate,
        closeRateEur: closeEur,
        bsiRateAtOpen: bsiOpen,
        bsiRateAtClose: bsiClose,
        hasLeverage: pos.leverage > 1,
        overnightFees: pos.overnightFees,
      ));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Crypto — parsano a ne exportano (pripravljeno za bodočo zakonodajo)
  // ---------------------------------------------------------------------------

  Future<List<CryptoTaxEvent>> _processCryptos(
      List<ClosedPosition> allPositions, int year) async {
    final cryptos = allPositions
        .where((p) =>
            p.type == InstrumentType.crypto && p.closeDate.year == year)
        .toList();

    final result = <CryptoTaxEvent>[];

    for (final pos in cryptos) {
      final bsiOpen = await _bsi.getUsdToEurRate(pos.openDate);
      final bsiClose = await _bsi.getUsdToEurRate(pos.closeDate);

      result.add(CryptoTaxEvent(
        name: pos.action,
        units: pos.units,
        openDate: pos.openDate,
        openRateEur: pos.openRateUsd * bsiOpen,
        closeDate: pos.closeDate,
        closeRateEur: pos.closeRateUsd * bsiClose,
        profitEur: pos.profitEur,
      ));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Dividende
  // ---------------------------------------------------------------------------

  Future<List<DividendTaxEvent>> _processDividends(
      List<DividendRecord> dividends, int year) async {
    final result = <DividendTaxEvent>[];

    for (final div in dividends.where((d) => d.date.year == year)) {
      // eToro že podaja EUR vrednost dividende
      // Za davčne namene pa vzamemo BSI tečaj na dan izplačila
      final bsiRate = await _bsi.getUsdToEurRate(div.date);
      final netEur = div.netDividendUsd * bsiRate;
      final taxEur = div.withholdingTaxUsd * bsiRate;

      result.add(DividendTaxEvent(
        date: div.date,
        instrumentName: div.instrumentName,
        isin: div.isin,
        netAmountEur: netEur,
        withholdingTaxEur: taxEur,
        withholdingTaxRatePct: div.withholdingTaxRatePct,
      ));
    }

    return result;
  }
}

/// FIFO lot — en nakup v vrsti
class _FifoLot {
  final DateTime date;
  final double priceEur;
  double units;
  final double bsiRate;
  final String instrumentName;

  _FifoLot({
    required this.date,
    required this.priceEur,
    required this.units,
    required this.bsiRate,
    required this.instrumentName,
  });
}