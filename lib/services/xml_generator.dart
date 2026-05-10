import 'package:xml/xml.dart';
import '../models/tax_event.dart';
import '../models/user_settings.dart';

/// Generira eDavki XML datoteke iz TaxReport
///
/// Podprte sheme:
///   Doh_KDVP_9  → delnice
///   D_IFI_4     → CFD
///   Doh_Div_3   → dividende
class XmlGenerator {
  final UserSettings settings;
  final TaxReport report;

  XmlGenerator({required this.settings, required this.report});

  // ---------------------------------------------------------------------------
  // Doh-KDVP — delnice
  // ---------------------------------------------------------------------------

  String generateKdvp() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('Envelope', namespaces: {
      'http://edavki.durs.si/Documents/Schemas/Doh_KDVP_9.xsd': '',
      'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd': 'edp',
    }, nest: () {
      _buildEdpHeader(builder, 'Doh_KDVP');
      _buildEdpSignatures(builder);

      builder.element('body', nest: () {
        builder.element('bodyContent', namespace: 'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd');

        builder.element('Doh_KDVP', nest: () {
          builder.element('KDVP', nest: () {
            builder.element('DocumentWorkflowID', nest: 'O');
            builder.element('Year', nest: report.year.toString());
            builder.element('PeriodStart', nest: '${report.year}-01-01');
            builder.element('PeriodEnd', nest: '${report.year}-12-31');
            builder.element('IsResident', nest: settings.isResident.toString());
            builder.element('SecurityCount',
                nest: report.stocks.map((e) => e.isin).toSet().length.toString());
            builder.element('SecurityShortCount', nest: '0');
            builder.element('SecurityWithContractCount', nest: '0');
            builder.element('SecurityWithContractShortCount', nest: '0');
            builder.element('ShareCount', nest: '0');
            if (settings.email.isNotEmpty) {
              builder.element('Email', nest: settings.email);
            }
            if (settings.phoneNumber.isNotEmpty) {
              builder.element('TelephoneNumber', nest: settings.phoneNumber);
            }
          });

          // En KDVPItem na ISIN
          final byIsin = <String, List<StockTaxEvent>>{};
          for (final e in report.stocks) {
            byIsin.putIfAbsent(e.isin, () => []).add(e);
          }

          int itemId = 1;
          for (final entry in byIsin.entries) {
            final isin = entry.key;
            final events = entry.value
              ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
            final name = events.first.name;

            builder.element('KDVPItem', nest: () {
              builder.element('ItemID', nest: itemId.toString());
              builder.element('InventoryListType', nest: 'PLVP');
              builder.element('Name', nest: name);
              builder.element('HasForeignTax', nest: 'false');

              builder.element('Securities', nest: () {
                builder.element('ISIN', nest: isin);
                builder.element('Code', nest: isin);
                builder.element('Name', nest: name);
                builder.element('IsFond', nest: 'false');

                int rowId = 1;

                // Zberi vse unikatne nakupe in prodaje
                // Format: nakup vrstica + prodaja vrstica izmenično (FIFO pari)
                for (final event in events) {
                  // Nakupna vrstica
                  builder.element('Row', nest: () {
                    builder.element('ID', nest: rowId.toString());
                    builder.element('Purchase', nest: () {
                      builder.element('F1',
                          nest: _formatDate(event.purchaseDate));
                      builder.element('F2', nest: 'B'); // nakup
                      builder.element('F3',
                          nest: _formatDecimal(event.units, 8));
                      builder.element('F4',
                          nest: _formatDecimal(event.purchaseRateEur, 8));
                    });
                  });
                  rowId++;

                  // Prodajna vrstica
                  builder.element('Row', nest: () {
                    builder.element('ID', nest: rowId.toString());
                    builder.element('Sale', nest: () {
                      builder.element('F6',
                          nest: _formatDate(event.saleDate));
                      builder.element('F7',
                          nest: _formatDecimal(event.units, 8));
                      builder.element('F9',
                          nest: _formatDecimal(event.saleRateEur, 8));
                      builder.element('F10', nest: 'false');
                    });
                  });
                  rowId++;
                }
              });
            });
            itemId++;
          }
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  // ---------------------------------------------------------------------------
  // D-IFI — CFD
  // ---------------------------------------------------------------------------

  String generateIfi() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('Envelope', namespaces: {
      'http://edavki.durs.si/Documents/Schemas/D_IFI_4.xsd': '',
      'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd': 'edp',
    }, nest: () {
      _buildEdpHeader(builder, 'D_IFI');
      _buildEdpSignatures(builder);

      builder.element('body', nest: () {
        builder.element('bodyContent',
            namespace: 'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd');

        builder.element('D_IFI', nest: () {
          builder.element('PeriodStart', nest: '${report.year}-01-01');
          builder.element('PeriodEnd', nest: '${report.year}-12-31');
          if (settings.email.isNotEmpty) {
            builder.element('Email', nest: settings.email);
          }
          if (settings.phoneNumber.isNotEmpty) {
            builder.element('TelephoneNumber', nest: settings.phoneNumber);
          }

          // Grupiraj Long in Short ločeno po imenu
          final longCfds =
              report.cfds.where((c) => c.isLong).toList();
          final shortCfds =
              report.cfds.where((c) => !c.isLong).toList();

          // Long CFD-ji → PLIFI
          final byNameLong = <String, List<CfdTaxEvent>>{};
          for (final c in longCfds) {
            byNameLong.putIfAbsent(c.name, () => []).add(c);
          }

          for (final entry in byNameLong.entries) {
            final events = entry.value
              ..sort((a, b) => a.openDate.compareTo(b.openDate));
            final first = events.first;

            builder.element('TItem', nest: () {
              builder.element('TypeId', nest: 'PLIFI');
              builder.element('Type', nest: '01'); // CFD
              builder.element('Name', nest: first.name);
              if (first.isin.isNotEmpty) {
                builder.element('ISIN', nest: first.isin);
              }
              builder.element('HasForeignTax', nest: 'false');

              for (final event in events) {
                // Nakup
                builder.element('TSubItem', nest: () {
                  builder.element('Purchase', nest: () {
                    builder.element('F1',
                        nest: _formatDate(event.openDate));
                    builder.element('F2', nest: 'B');
                    builder.element('F3',
                        nest: _formatDecimal(event.units, 8));
                    builder.element('F4',
                        nest: _formatDecimal(event.openRateEur, 8));
                    builder.element('F9',
                        nest: event.hasLeverage.toString());
                  });
                });

                // Prodaja
                builder.element('TSubItem', nest: () {
                  builder.element('Sale', nest: () {
                    builder.element('F5',
                        nest: _formatDate(event.closeDate));
                    builder.element('F6',
                        nest: _formatDecimal(event.units, 8));
                    builder.element('F7',
                        nest: _formatDecimal(event.closeRateEur, 8));
                  });
                });
              }
            });
          }

          // Short CFD-ji → PLIFIShort
          final byNameShort = <String, List<CfdTaxEvent>>{};
          for (final c in shortCfds) {
            byNameShort.putIfAbsent(c.name, () => []).add(c);
          }

          for (final entry in byNameShort.entries) {
            final events = entry.value
              ..sort((a, b) => a.openDate.compareTo(b.openDate));
            final first = events.first;

            builder.element('TItem', nest: () {
              builder.element('TypeId', nest: 'PLIFIShort');
              builder.element('Type', nest: '01');
              builder.element('Name', nest: first.name);
              if (first.isin.isNotEmpty) {
                builder.element('ISIN', nest: first.isin);
              }
              builder.element('HasForeignTax', nest: 'false');

              for (final event in events) {
                builder.element('TShortSubItem', nest: () {
                  builder.element('Sale', nest: () {
                    builder.element('F1',
                        nest: _formatDate(event.openDate));
                    builder.element('F2',
                        nest: _formatDecimal(event.units, 8));
                    builder.element('F3',
                        nest: _formatDecimal(event.openRateEur, 8));
                    builder.element('F9',
                        nest: event.hasLeverage.toString());
                  });
                  builder.element('Purchase', nest: () {
                    builder.element('F4',
                        nest: _formatDate(event.closeDate));
                    builder.element('F5', nest: 'B');
                    builder.element('F6',
                        nest: _formatDecimal(event.units, 8));
                    builder.element('F7',
                        nest: _formatDecimal(event.closeRateEur, 8));
                  });
                });
              }
            });
          }
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  // ---------------------------------------------------------------------------
  // Doh-Div — dividende
  // ---------------------------------------------------------------------------

  String generateDiv() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element('Envelope', namespaces: {
      'http://edavki.durs.si/Documents/Schemas/Doh_Div_3.xsd': '',
      'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd': 'edp',
    }, nest: () {
      _buildEdpHeader(builder, 'Doh_Div');
      _buildEdpSignatures(builder);

      builder.element('body', nest: () {
        builder.element('Doh_Div', nest: () {
          builder.element('Period', nest: report.year.toString());
          if (settings.email.isNotEmpty) {
            builder.element('EmailAddress', nest: settings.email);
          }
          if (settings.phoneNumber.isNotEmpty) {
            builder.element('PhoneNumber', nest: settings.phoneNumber);
          }
          builder.element('IsResident', nest: settings.isResident.toString());
          builder.element('SelfReport', nest: 'true');
        });

        for (final div in report.dividends) {
          builder.element('Dividend', nest: () {
            builder.element('Date', nest: _formatDate(div.date));
            builder.element('PayerName', nest: DividendTaxEvent.payerName);
            builder.element('PayerAddress', nest: DividendTaxEvent.payerAddress);
            builder.element('PayerCountry', nest: DividendTaxEvent.payerCountry);
            builder.element('Type', nest: '1'); // dividenda
            builder.element('Value',
                nest: _formatDecimal(div.grossAmountEur, 2));
            builder.element('ForeignTax',
                nest: _formatDecimal(div.withholdingTaxEur, 2));
            builder.element('SourceCountry', nest: 'US'); // večina eToro delnic je US
          });
        }
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  // ---------------------------------------------------------------------------
  // Skupni EDP header (enak za vse obrazce)
  // ---------------------------------------------------------------------------

  void _buildEdpHeader(XmlBuilder b, String formType) {
    b.element('Header',
        namespace: 'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
        nest: () {
      b.element('taxpayer',
          namespace:
              'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
          nest: () {
        b.element('taxNumber',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: settings.taxNumber);
        b.element('taxpayerType',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: 'FO'); // fizična oseba
        b.element('name',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: settings.fullName);
        b.element('address',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: '');
        b.element('city',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: '');
        b.element('postNumber',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: '');
        b.element('postName',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: '');
      });
      b.element('Workflow',
          namespace:
              'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
          nest: () {
        b.element('DocumentWorkflowID',
            namespace:
                'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd',
            nest: 'O');
      });
    });
  }

  void _buildEdpSignatures(XmlBuilder b) {
    b.element('Signatures',
        namespace: 'http://edavki.durs.si/Documents/Schemas/EDP-Common-1.xsd');
  }

  // ---------------------------------------------------------------------------
  // Format pomočniki
  // ---------------------------------------------------------------------------

  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _formatDecimal(double value, int decimals) {
    return value.toStringAsFixed(decimals);
  }
}