import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BlockedScreen extends StatelessWidget {
  final String message;

  const BlockedScreen({super.key, required this.message});

  static const _webUrl = 'https://keybusy-software.vercel.app/';

  Future<void> _launchWeb() async {
    final uri = Uri.parse(_webUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback: webview interno si el navegador externo no está disponible
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícono candado
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: cs.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Título
                  Text(
                    'Servicio suspendido',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Mensaje configurable desde Supabase
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                  const SizedBox(height: 48),

                  // Divisor
                  Divider(color: cs.outlineVariant),
                  const SizedBox(height: 24),

                  // Texto "contactar proveedor"
                  Text(
                    'Para regularizar tu servicio,\nvisita nuestra página:',
                    style: textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Botón web
                  FilledButton.icon(
                    onPressed: _launchWeb,
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('keybusy-software.vercel.app'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
