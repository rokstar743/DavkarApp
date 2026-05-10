import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/xlsx_parser.dart';
import 'review_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _processing = false;
  String? _error;
  String _statusMsg = '';

  Future<void> _pickFile() async {
    setState(() { _error = null; });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _error = 'Datoteke ni bilo mogoče prebrati.');
      return;
    }

    setState(() {
      _processing = true;
      _statusMsg = 'Pretvarjam xlsx...';
    });

    try {
      // Zapiši bytes v temp datoteko ker converter.exe potrebuje pot
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${file.name}');
      await tempFile.writeAsBytes(file.bytes!);

      setState(() => _statusMsg = 'Berem transakcije...');
      final report = await XlsxParser.parseXlsx(tempFile.path);

      // Počisti temp
      try { await tempFile.delete(); } catch (_) {}

      if (report.closedPositions.isEmpty && report.dividends.isEmpty) {
        setState(() {
          _processing = false;
          _error = 'V datoteki ni bilo najdenih transakcij. '
              'Preverite, ali ste izvozili pravo datoteko (eToro Account Statement).';
        });
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReviewScreen(report: report)),
      );
      setState(() => _processing = false);
    } catch (e) {
      setState(() {
        _processing = false;
        _error = 'Napaka: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uvozi eToro poročilo'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text('Kako izvoziti poročilo iz eTora',
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    ..._steps.map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22, height: 22,
                                margin: const EdgeInsets.only(right: 8, top: 1),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(step['num']!,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Expanded(
                                child: Text(step['text']!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onPrimaryContainer)),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade800, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Obvezno nastavi celotno obdobje trgovanja, '
                            'ne samo zadnje leto — FIFO metoda potrebuje vse pretekle nakupe.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orange.shade900),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            if (_processing)
              Column(children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_statusMsg),
              ])
            else
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: theme.colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.primary.withOpacity(0.04),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text('Klikni za izbiro xlsx datoteke',
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('eToro Account Statement (.xlsx)',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: TextStyle(
                                color: theme.colorScheme.onErrorContainer))),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _steps = [
    {'num': '1', 'text': 'Odpri eToro'},
    {'num': '2', 'text': 'Pojdi v Nastavitve (Settings)'},
    {'num': '3', 'text': 'Pojdi pod zavihek Račun (Account)'},
    {'num': '4', 'text': 'Pod razdelkom Dokumenti (Documents) izberi Izpis računa (Account statement)'},
    {'num': '5', 'text': 'Izberi Po meri (Custom) in nastavi celotno obdobje trgovanja'},
    {'num': '6', 'text': 'Prenesi .xlsx datoteko'},
  ];
}