import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = context.watch<ThemeSettings>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              title: const Text('Modo oscuro'),
              subtitle: const Text('Usar una apariencia oscura en la aplicación'),
              secondary: Icon(
                themeSettings.isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              value: themeSettings.isDarkMode,
              onChanged: themeSettings.setDarkMode,
            ),
          ),
        ],
      ),
    );
  }
}
