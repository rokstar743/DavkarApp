import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/user_settings.dart';
import 'import_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await SettingsService().load();
    setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsOk = _settings?.isValid ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DavkarApp'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _loadSettings();
            },
            icon: Stack(
              children: [
                const Icon(Icons.settings_outlined),
                if (!settingsOk)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Nastavitve',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 16),
                  Text('DavkarApp',
                      style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Pretvori eToro Account Statement v XML datoteke '
                    'za uvoz na eDavki portal.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Opozorilo za nastavitve
            if (!settingsOk)
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded,
                      color: theme.colorScheme.error),
                  title: const Text('Davčni podatki niso nastavljeni'),
                  subtitle: const Text(
                      'Pred uvozom nastavi davčno številko in ime'),
                  trailing: TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                      _loadSettings();
                    },
                    child: const Text('Nastavi'),
                  ),
                ),
              ),

            if (_settings != null && settingsOk)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: Icon(Icons.verified_user_outlined,
                      color: theme.colorScheme.secondary),
                  title: Text(_settings!.fullName),
                  subtitle: Text('Davčna: ${_settings!.taxNumber}'),
                  trailing: TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                      _loadSettings();
                    },
                    child: const Text('Uredi'),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            Text('Podprte napovedi',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            ..._supportedForms.map((form) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (form['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(form['icon'] as IconData,
                          color: form['color'] as Color),
                    ),
                    title: Text(form['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(form['subtitle'] as String),
                    trailing: Chip(
                      label: Text(form['tag'] as String,
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor:
                          (form['color'] as Color).withOpacity(0.15),
                    ),
                  ),
                )),

            const SizedBox(height: 32),

            // Glavni gumb
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImportScreen()),
                ),
                icon: const Icon(Icons.upload_file),
                label: const Text('Uvozi eToro poročilo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Izdelovalec aplikacije ni odgovoren za napake v izvoženih podatkih. '
                      'Pred oddajo na FURS vedno preveri izvožene XML datoteke.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Odprtokodna aplikacija • Podatki ostanejo lokalno',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _supportedForms = [
    {
      'title': 'Doh-KDVP',
      'subtitle': 'Delnice — dejanske "real stocks" pozicije',
      'tag': 'FIFO',
      'icon': Icons.show_chart,
      'color': Colors.green,
    },
    {
      'title': 'D-IFI',
      'subtitle': 'CFD — izvedeni finančni instrumenti, Long & Short',
      'tag': 'CFD',
      'icon': Icons.candlestick_chart_outlined,
      'color': Colors.blue,
    },
    {
      'title': 'Doh-Div',
      'subtitle': 'Dividende z zadržanim davkom',
      'tag': 'DIV',
      'icon': Icons.payments_outlined,
      'color': Colors.purple,
    },
  ];
}