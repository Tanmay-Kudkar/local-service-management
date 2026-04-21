import 'package:flutter/material.dart';

import '../services/api_service.dart';

String serverModeLabel(ApiServerMode mode) {
  return switch (mode) {
    ApiServerMode.deployed => 'Deployed Server',
    ApiServerMode.local => 'Localhost (Emulator)',
  };
}

String serverModeSubtitle(ApiServerMode mode) {
  return switch (mode) {
    ApiServerMode.deployed => 'https://servico-app-server.onrender.com',
    ApiServerMode.local => 'http://10.0.2.2:8080',
  };
}

Future<ApiServerMode?> showServerModeSelectorSheet(
  BuildContext context,
  ApiServerMode currentMode,
) {
  return showModalBottomSheet<ApiServerMode>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ApiServerMode.values)
              RadioListTile<ApiServerMode>(
                value: mode,
                groupValue: currentMode,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  Navigator.pop(sheetContext, value);
                },
                title: Text(serverModeLabel(mode)),
                subtitle: Text(serverModeSubtitle(mode)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
