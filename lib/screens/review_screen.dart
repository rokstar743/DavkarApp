import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/etoro_transaction.dart';
import '../models/tax_event.dart';
import '../services/bsi_exchange.dart';
import '../services/fifo_engine.dart';
import '../services/settings_service.dart';
import '../models/user_settings.dart';
import '../widgets/transaction_table.dart';
import '../widgets/summary_card.dart';
import 'export_screen.dart';

class ReviewScreen extends StatefulWidget {
  final EtoroReport report;

  const ReviewScreen({super.key, required this.report});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedYear;
  TaxReport? _taxReport;
  UserSettings? _settings;
  bool _processing = false;
  String? _error;
  String _statusMsg = '';

  final _fmt = NumberFormat('#,##0.00', 'sl_SI');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await SettingsService().load();
    setState(() => _settings = s);
  }

  Future<void> _process() async {
    if (_selectedYear == null) return;

    if (_settings == null || !_settings!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Najprej izpolni nastavitve (davčna številka, ime)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
      _taxReport = null;
      _statusMsg = 'Pridobivam BSI tečaje...';
    });

    try {
      final bsi = BsiExchangeService();
      final engine = FifoEngine(bsi);

      setState(() => _statusMsg = 'Procesiranje FIFO...');
      final report =
          await engine.process(widget.report, _selectedYear!);

      setState(() {
        _taxReport = report;
        _processing = false;
        _statusMsg = '';
      });
    } catch (e) {
      setState(() {
        _processing = false;
        _error = e.toString();
        _statusMsg = '';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = widget.report.availableYears;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregled transakcij'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        actions: [
          if (_taxReport != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExportScreen(
                      taxReport: _taxReport!,
                      settings: _settings!,
                    ),
                  ),
                ),
                icon: const Icon(Icons.download),
                label: const Text('Izvozi XML'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Izbira leta + gumb za procesiranje
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Text('Davčno leto:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _selectedYear,
                  hint: const Text('Izberi leto'),
                  items: years
                      .map((y) => DropdownMenuItem(
                          value: y, child: Text(y.toString())))
                      .toList(),
                  onChanged: (y) {
                    setState(() {
                      _selectedYear = y;
                      _taxReport = null;
                      _error = null;
                    });
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: (_selectedYear != null && !_processing)
                      ? _process
                      : null,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: Text(_processing ? _statusMsg : 'Izračunaj'),
                ),
              ],
            ),
          ),

          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.errorContainer,
              child: Text(_error!,
                  style:
                      TextStyle(color: theme.colorScheme.onErrorContainer)),
            ),

          if (_taxReport != null) ...[
            // Summary cards
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: 'Delnice (dobiček)',
                      value:
                          '${_fmt.format(_taxReport!.totalStockProfitEur)} EUR',
                      subtitle: '${_taxReport!.stocks.length} poslov',
                      icon: Icons.show_chart,
                      color: _taxReport!.totalStockProfitEur >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SummaryCard(
                      title: 'CFD (dobiček)',
                      value:
                          '${_fmt.format(_taxReport!.totalCfdProfitEur)} EUR',
                      subtitle: '${_taxReport!.cfds.length} poslov',
                      icon: Icons.candlestick_chart_outlined,
                      color: _taxReport!.totalCfdProfitEur >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SummaryCard(
                      title: 'Dividende (bruto)',
                      value:
                          '${_fmt.format(_taxReport!.totalDividendEur)} EUR',
                      subtitle: '${_taxReport!.dividends.length} izplačil',
                      icon: Icons.payments_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                    text:
                        'Delnice (${_taxReport!.stocks.length})'),
                Tab(text: 'CFD (${_taxReport!.cfds.length})'),
                Tab(
                    text:
                        'Dividende (${_taxReport!.dividends.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: StockTaxTable(events: _taxReport!.stocks),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CfdTaxTable(events: _taxReport!.cfds),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: DividendTaxTable(
                        events: _taxReport!.dividends),
                  ),
                ],
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: _processing
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_statusMsg),
                          const SizedBox(height: 8),
                          Text(
                            'Pridobivam BSI tečaje za vsak datum posla...',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calculate_outlined,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            _selectedYear == null
                                ? 'Izberi davčno leto in klikni Izračunaj'
                                : 'Klikni Izračunaj za procesiranje',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}