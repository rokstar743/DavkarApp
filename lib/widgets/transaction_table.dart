import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tax_event.dart';

class StockTaxTable extends StatelessWidget {
  final List<StockTaxEvent> events;

  const StockTaxTable({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'sl_SI');
    final dateFmt = DateFormat('dd.MM.yyyy');

    if (events.isEmpty) {
      return const Center(child: Text('Ni delniških transakcij.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
        columns: const [
          DataColumn(label: Text('Instrument')),
          DataColumn(label: Text('ISIN')),
          DataColumn(label: Text('Enote'), numeric: true),
          DataColumn(label: Text('Datum nakupa')),
          DataColumn(label: Text('Nabavna cena (EUR)'), numeric: true),
          DataColumn(label: Text('Datum prodaje')),
          DataColumn(label: Text('Prodajna cena (EUR)'), numeric: true),
          DataColumn(label: Text('Dobiček (EUR)'), numeric: true),
        ],
        rows: events.map((e) {
          final profit = e.profitEur;
          final profitColor = profit >= 0 ? Colors.green[700] : Colors.red[700];

          return DataRow(cells: [
            DataCell(Text(e.name, overflow: TextOverflow.ellipsis)),
            DataCell(Text(e.isin)),
            DataCell(Text(e.units.toStringAsFixed(4))),
            DataCell(Text(dateFmt.format(e.purchaseDate))),
            DataCell(Text(fmt.format(e.purchaseRateEur))),
            DataCell(Text(dateFmt.format(e.saleDate))),
            DataCell(Text(fmt.format(e.saleRateEur))),
            DataCell(Text(
              '${profit >= 0 ? '+' : ''}${fmt.format(profit)}',
              style: TextStyle(
                  color: profitColor, fontWeight: FontWeight.w600),
            )),
          ]);
        }).toList(),
      ),
    );
  }
}

class CfdTaxTable extends StatelessWidget {
  final List<CfdTaxEvent> events;

  const CfdTaxTable({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'sl_SI');
    final dateFmt = DateFormat('dd.MM.yyyy');

    if (events.isEmpty) {
      return const Center(child: Text('Ni CFD transakcij.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
        columns: const [
          DataColumn(label: Text('Instrument')),
          DataColumn(label: Text('Smer')),
          DataColumn(label: Text('Enote'), numeric: true),
          DataColumn(label: Text('Datum odprtja')),
          DataColumn(label: Text('Cena odprtja (EUR)'), numeric: true),
          DataColumn(label: Text('Datum zaprtja')),
          DataColumn(label: Text('Cena zaprtja (EUR)'), numeric: true),
          DataColumn(label: Text('Dobiček (EUR)'), numeric: true),
          DataColumn(label: Text('Vzvod')),
        ],
        rows: events.map((e) {
          final profit = e.profitEur;
          final profitColor = profit >= 0 ? Colors.green[700] : Colors.red[700];

          return DataRow(cells: [
            DataCell(Text(e.name, overflow: TextOverflow.ellipsis)),
            DataCell(Text(e.isLong ? 'Long' : 'Short')),
            DataCell(Text(e.units.toStringAsFixed(4))),
            DataCell(Text(dateFmt.format(e.openDate))),
            DataCell(Text(fmt.format(e.openRateEur))),
            DataCell(Text(dateFmt.format(e.closeDate))),
            DataCell(Text(fmt.format(e.closeRateEur))),
            DataCell(Text(
              '${profit >= 0 ? '+' : ''}${fmt.format(profit)}',
              style: TextStyle(color: profitColor, fontWeight: FontWeight.w600),
            )),
            DataCell(Text(e.hasLeverage ? 'Da' : 'Ne')),
          ]);
        }).toList(),
      ),
    );
  }
}

class DividendTaxTable extends StatelessWidget {
  final List<DividendTaxEvent> events;

  const DividendTaxTable({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'sl_SI');
    final dateFmt = DateFormat('dd.MM.yyyy');

    if (events.isEmpty) {
      return const Center(child: Text('Ni dividend.'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
        columns: const [
          DataColumn(label: Text('Instrument')),
          DataColumn(label: Text('Datum')),
          DataColumn(label: Text('Bruto (EUR)'), numeric: true),
          DataColumn(label: Text('Zadržan davek (EUR)'), numeric: true),
          DataColumn(label: Text('Stopnja %'), numeric: true),
          DataColumn(label: Text('Neto (EUR)'), numeric: true),
        ],
        rows: events.map((e) {
          return DataRow(cells: [
            DataCell(Text(e.instrumentName, overflow: TextOverflow.ellipsis)),
            DataCell(Text(dateFmt.format(e.date))),
            DataCell(Text(fmt.format(e.grossAmountEur))),
            DataCell(Text(fmt.format(e.withholdingTaxEur))),
            DataCell(Text('${e.withholdingTaxRatePct.toStringAsFixed(1)} %')),
            DataCell(Text(fmt.format(e.netAmountEur))),
          ]);
        }).toList(),
      ),
    );
  }
}