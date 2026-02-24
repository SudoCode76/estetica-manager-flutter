import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _website = 'https://keybusy-software.vercel.app/';
  static const _whatsappNumber = '+59162994685';

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(_website);
    try {
      debugPrint('AboutScreen: intentando abrir sitio web: $uri');
      // 1) Intentar abrir en aplicación externa (navegador)
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication)
          .catchError((e) {
            debugPrint('launchUrl externalApplication error: $e');
            return false;
          });

      // 2) Fallback: intentar con mode platformDefault
      if (!launched) {
        debugPrint('AboutScreen: fallback a platformDefault');
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault)
            .catchError((e) {
              debugPrint('launchUrl platformDefault error: $e');
              return false;
            });
      }

      // 3) Último recurso: usar launchUrlString
      if (!launched) {
        debugPrint('AboutScreen: fallback a launchUrlString');
        try {
          launched =
              await launchUrl(
                Uri.parse(_website),
                mode: LaunchMode.externalApplication,
              ).catchError((e) {
                debugPrint('launchUrl fallback error: $e');
                return false;
              });
        } catch (e) {
          debugPrint('launchUrl fallback error: $e');
          launched = false;
        }
      }

      if (!launched) {
        // Mostrar diálogo con la URL para copiar manualmente
        await _showManualLinkDialog(context, _website, 'Abrir sitio web');
      }
    } catch (e) {
      debugPrint('AboutScreen._openWebsite error: $e');
      await _showManualLinkDialog(context, _website, 'Abrir sitio web');
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    // Usamos api.whatsapp.com para mejor compatibilidad en Android
    final phone = _whatsappNumber.replaceAll('+', '');
    final webUri = Uri.parse('https://api.whatsapp.com/send?phone=$phone');
    final waUri = Uri.parse('whatsapp://send?phone=$phone');

    debugPrint('AboutScreen: intentando abrir WhatsApp (web): $webUri');
    bool launched = false;

    // 1) Intentar esquema nativo whatsapp:// (si la app está instalada)
    try {
      launched = await launchUrl(waUri, mode: LaunchMode.externalApplication)
          .catchError((e) {
            debugPrint('launchUrl whatsapp:// error: $e');
            return false;
          });
    } catch (e) {
      debugPrint('whatsapp native scheme error: $e');
      launched = false;
    }

    // 2) Fallback: abrir en web (api.whatsapp.com)
    if (!launched) {
      try {
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication)
            .catchError((e) {
              debugPrint('launchUrl web whatsapp error: $e');
              return false;
            });
      } catch (e) {
        debugPrint('web whatsapp launch error: $e');
        launched = false;
      }
    }

    // 3) fallback a launchUrlString
    if (!launched) {
      try {
        launched =
            await launchUrl(
              Uri.parse(webUri.toString()),
              mode: LaunchMode.externalApplication,
            ).catchError((e) {
              debugPrint('launchUrlString whatsapp fallback error: $e');
              return false;
            });
      } catch (e) {
        debugPrint('launchUrl whatsapp fallback error: $e');
        launched = false;
      }
    }

    if (!launched) {
      await _showManualLinkDialog(
        context,
        webUri.toString(),
        'Abrir WhatsApp (web)',
      );
    }
  }

  Future<void> _showManualLinkDialog(
    BuildContext context,
    String url,
    String title,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No se pudo abrir automáticamente. Copia el enlace y pégalo en tu navegador o app:',
            ),
            const SizedBox(height: 12),
            SelectableText(url, style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enlace copiado al portapapeles')),
              );
            },
            child: const Text('Copiar enlace'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              'Control Estética',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Versión 1.0.0',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.primary),
            ),
            const SizedBox(height: 18),

            // Card con info desarrollador
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha((0.06 * 255).toInt()),
                borderRadius: BorderRadius.circular(22),
                // ligera sombra
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'DESARROLLADO POR',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'KeyBusy Software',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Creamos soluciones digitales intuitivas para potenciar tu negocio de estética.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Botón visitar sitio
            FilledButton.icon(
              onPressed: () => _openWebsite(context),
              icon: const Icon(Icons.public),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Visitar sitio web',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),

            const SizedBox(height: 16),

            // Botón WhatsApp
            FilledButton.icon(
              onPressed: () => _openWhatsApp(context),
              icon: Icon(Icons.chat, color: Colors.white),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Contactar por WhatsApp',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),

            const SizedBox(height: 36),

            // Footer copyright
            Column(
              children: [
                Divider(color: cs.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  '© 2026 KeyBusy Software',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
