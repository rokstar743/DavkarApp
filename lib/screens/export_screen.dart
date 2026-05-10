import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/tax_event.dart';
import '../models/user_settings.dart';
import '../services/xml_generator.dart';

class ExportScreen extends StatefulWidget {
  final TaxReport taxReport;
  final UserSettings settings;

  const ExportScreen({
    super.key,
    required this.taxReport,
    required this.settings,
  });

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _generating = false;
  List<_ExportedFile> _files = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
      _files = [];
    });

    try {
      final gen = XmlGenerator(
        settings: widget.settings,
        report: widget.taxReport,
      );

      final dir = await _getOutputDir();
      final year = widget.taxReport.year;
      final exported = <_ExportedFile>[];

      if (widget.taxReport.hasStocks) {
        final xml = gen.generateKdvp();
        final file = File('${dir.path}/Doh-KDVP-$year.xml');
        await file.writeAsString(xml);
        exported.add(_ExportedFile(
          label: 'Doh-KDVP (delnice)',
          path: file.path,
          description: 'Napoved za odmero dohodnine od dobička od odsvojitve vrednostnih papirjev',
          records: widget.taxReport.stocks.length,
        ));
      }

      if (widget.taxReport.hasCfds) {
        final xml = gen.generateIfi();
        final file = File('${dir.path}/D-IFI-$year.xml');
        await file.writeAsString(xml);
        exported.add(_ExportedFile(
          label: 'D-IFI (CFD)',
          path: file.path,
          description: 'Napoved za odmero dohodnine od dobička iz izvedenih finančnih instrumentov',
          records: widget.taxReport.cfds.length,
        ));
      }

      if (widget.taxReport.hasDividends) {
        final xml = gen.generateDiv();
        final file = File('${dir.path}/Doh-Div-$year.xml');
        await file.writeAsString(xml);
        exported.add(_ExportedFile(
          label: 'Doh-Div (dividende)',
          path: file.path,
          description: 'Napoved za odmero dohodnine od dividend',
          records: widget.taxReport.dividends.length,
        ));
      }

      if (exported.isEmpty) {
        setState(() {
          _generating = false;
          _error = 'Za izbrano leto ni bilo najdenih transakcij za izvoz.';
        });
        return;
      }

      setState(() {
        _generating = false;
        _files = exported;
      });
    } catch (e) {
      setState(() {
        _generating = false;
        _error = 'Napaka pri generiranju XML: $e';
      });
    }
  }

  Future<Directory> _getOutputDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/DavkarApp');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final year = widget.taxReport.year;

    return Scaffold(
      appBar: AppBar(
        title: Text('Izvoz XML — $year'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      body: _generating
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generiram XML datoteke...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _generate,
                            child: const Text('Poskusi znova')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Uspeh header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade700, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Generirano ${_files.length} XML ${_files.length == 1 ? "datoteka" : "datoteke"}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800),
                                  ),
                                  Text(
                                    'Datoteke so shranjene v Dokumenti/DavkarApp/',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.green.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text('Generirane datoteke',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      ..._files.map((f) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.description_outlined,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(f.label,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      Chip(
                                        label: Text('${f.records} poslov'),
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(f.description,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurfaceVariant)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.folder_outlined,
                                            size: 14,
                                            color: theme.colorScheme
                                                .onSurfaceVariant),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(f.path,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      fontFamily: 'monospace')),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }
}

class _ExportedFile {
  final String label;
  final String path;
  final String description;
  final int records;

  const _ExportedFile({
    required this.label,
    required this.path,
    required this.description,
    required this.records,
  });
}