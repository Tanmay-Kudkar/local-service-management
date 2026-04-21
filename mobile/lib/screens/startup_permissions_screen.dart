import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

class StartupPermissionsScreen extends StatefulWidget {
  final Widget nextScreen;

  const StartupPermissionsScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<StartupPermissionsScreen> createState() => _StartupPermissionsScreenState();
}

class _StartupPermissionsScreenState extends State<StartupPermissionsScreen> {
  static const String _prefsKey = 'startupPermissionsPrompted';

  bool _isLoading = true;
  bool _isRequesting = false;
  bool _showApp = false;

  final Map<String, PermissionStatus> _statuses = {
    'Location': PermissionStatus.denied,
    'Camera': PermissionStatus.denied,
    'Photos': PermissionStatus.denied,
  };

  @override
  void initState() {
    super.initState();
    _initAndRequestPermissions();
  }

  Future<void> _initAndRequestPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_prefsKey) ?? false;

    if (!mounted) {
      return;
    }

    if (alreadyPrompted) {
      setState(() {
        _isLoading = false;
        _showApp = true;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });

    await _requestAllPermissions();

    if (!mounted) {
      return;
    }

    await prefs.setBool(_prefsKey, true);
    if (!mounted) {
      return;
    }

    setState(() {
      _showApp = true;
    });
  }

  Future<void> _requestAllPermissions() async {
    if (_isRequesting) {
      return;
    }

    setState(() {
      _isRequesting = true;
    });

    await _requestPermission('Location', Permission.locationWhenInUse);
    await _requestPermission('Camera', Permission.camera);

    if (Platform.isAndroid || Platform.isIOS) {
      await _requestPermission('Photos', Permission.photos);
    } else {
      setState(() {
        _statuses['Photos'] = PermissionStatus.granted;
      });
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRequesting = false;
    });
  }

  Future<void> _requestPermission(String key, Permission permission) async {
    final status = await permission.request();

    if (!mounted) {
      return;
    }

    setState(() {
      _statuses[key] = status;
    });
  }

  bool get _hasPermanentlyDenied {
    return _statuses.values.any((status) => status.isPermanentlyDenied);
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp) {
      return widget.nextScreen;
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preparing your app',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Requesting location, camera, and photos permissions before continuing.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _PermissionRow(label: 'Location', status: _statuses['Location']!),
                      const SizedBox(height: 10),
                      _PermissionRow(label: 'Camera', status: _statuses['Camera']!),
                      const SizedBox(height: 10),
                      _PermissionRow(label: 'Photos', status: _statuses['Photos']!),
                      const SizedBox(height: 16),
                      if (_isLoading || _isRequesting)
                        const LinearProgressIndicator(minHeight: 4),
                      if (_hasPermanentlyDenied) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: openAppSettings,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Open App Settings'),
                        ),
                      ],
                    ],
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

class _PermissionRow extends StatelessWidget {
  final String label;
  final PermissionStatus status;

  const _PermissionRow({
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final icon = status.isGranted
        ? Icons.check_circle_rounded
        : (status.isPermanentlyDenied
            ? Icons.block_rounded
            : Icons.pending_outlined);

    final color = status.isGranted
      ? const Color(0xFF2D8F4E)
      : (status.isPermanentlyDenied
        ? const Color(0xFFC53A3A)
        : AppTheme.textSecondary);

    final message = status.isGranted
        ? 'Granted'
        : (status.isPermanentlyDenied ? 'Denied forever' : 'Waiting');

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
