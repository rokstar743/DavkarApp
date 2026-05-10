import 'package:flutter/material.dart';
import '../models/user_settings.dart';
import '../services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taxNumberCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isResident = true;
  bool _loading = true;
  bool _saved = false;

  final _service = SettingsService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _service.load();
    setState(() {
      _taxNumberCtrl.text = s.taxNumber;
      _fullNameCtrl.text = s.fullName;
      _emailCtrl.text = s.email;
      _phoneCtrl.text = s.phoneNumber;
      _isResident = s.isResident;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final settings = UserSettings(
      taxNumber: _taxNumberCtrl.text.trim(),
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      isResident: _isResident,
    );
    await _service.save(settings);
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  void dispose() {
    _taxNumberCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavitve'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Osebni podatki',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Podatki se shranijo lokalno na napravi in se vključijo v XML datoteke.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _taxNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Davčna številka *',
                  hintText: '12345678',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                keyboardType: TextInputType.number,
                maxLength: 8,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Obvezno polje';
                  if (!RegExp(r'^\d{8}$').hasMatch(v)) {
                    return 'Davčna številka mora imeti točno 8 številk';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _fullNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ime in priimek *',
                  hintText: 'Janez Novak',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obvezno polje' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-pošta (neobvezno)',
                  hintText: 'janez@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefonska številka (neobvezno)',
                  hintText: '+38641123456',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Rezident Republike Slovenije'),
                subtitle: const Text('Označite, če ste davčni rezident RS'),
                value: _isResident,
                onChanged: (v) => setState(() => _isResident = v),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: Icon(_saved ? Icons.check : Icons.save_outlined),
                  label: Text(_saved ? 'Shranjeno!' : 'Shrani nastavitve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saved
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.lock_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('Zasebnost',
                            style: Theme.of(context).textTheme.labelLarge),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        'Vsi podatki se shranjujejo izključno lokalno na vaši napravi. '
                        'Nobeni osebni podatki se ne pošiljajo na internet, '
                        'razen anonimnih poizvedb na BSI API za tečaje valut.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Počisti podatke'),
                      content: const Text(
                          'Ali res želiš izbrisati vse shranjene nastavitve?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Prekliči')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Izbriši',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    setState(() {
                      _taxNumberCtrl.clear();
                      _fullNameCtrl.clear();
                      _emailCtrl.clear();
                      _phoneCtrl.clear();
                      _isResident = true;
                    });
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Počisti vse podatke'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}