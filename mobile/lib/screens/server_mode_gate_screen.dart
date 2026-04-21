import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/server_selector_sheet.dart';

class ServerModeGateScreen extends StatefulWidget {
  final Widget nextScreen;

  const ServerModeGateScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<ServerModeGateScreen> createState() => _ServerModeGateScreenState();
}

class _ServerModeGateScreenState extends State<ServerModeGateScreen> {
  bool _isChecking = true;
  bool _needsSelection = false;
  bool _isSaving = false;
  ApiServerMode _selectedMode = ApiServerMode.deployed;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final mode = await ApiService.getServerMode();
    final hasStoredChoice = await ApiService.hasStoredServerModeChoice();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMode = mode;
      _needsSelection =
          ApiService.isServerModeRuntimeConfigurable && !hasStoredChoice;
      _isChecking = false;
    });
  }

  Future<void> _continueWithSelection() async {
    setState(() {
      _isSaving = true;
    });

    await ApiService.setServerMode(_selectedMode);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _needsSelection = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }

    if (!_needsSelection) {
      return widget.nextScreen;
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose App Server',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pick where the app should connect. This is saved on your device until you change it manually.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        for (final mode in ApiServerMode.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ServerOptionCard(
                              title: serverModeLabel(mode),
                              subtitle: serverModeSubtitle(mode),
                              isRecommended: mode == ApiServerMode.deployed,
                              selected: _selectedMode == mode,
                              onTap: () {
                                setState(() {
                                  _selectedMode = mode;
                                });
                              },
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          'You can change this later from the cloud icon in the app header.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _continueWithSelection,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded),
                            label: Text(_isSaving ? 'Saving...' : 'Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool isRecommended;
  final VoidCallback onTap;

  const _ServerOptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = selected ? AppTheme.brand : const Color(0xFFCFDCDD);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selectedColor, width: selected ? 1.8 : 1),
            color: selected
                ? const Color(0xFFE9F6F3)
                : Colors.white.withValues(alpha: 0.65),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppTheme.brand : const Color(0xFF7A8A89),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD8F3E8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Recommended',
                              style: TextStyle(
                                color: Color(0xFF0A7D5B),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
