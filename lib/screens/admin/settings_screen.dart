import 'package:flutter/material.dart';
import 'package:app_estetica/screens/admin/reports_screen.dart';

/// Esta pantalla fue removida del menú. La mantenemos solo como marcador
/// por compatibilidad accidental con rutas. Navega a Reportes.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración (eliminada)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('La página de configuración fue eliminada del menú.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Usa la sección de Reportes o ajusta la configuración desde el backend.', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Ir a Reportes')),
            ],
          ),
        ),
      ),
    );
  }
}
