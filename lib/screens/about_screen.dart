import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_estetica/widgets/app_ui.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _website = 'https://keybusy-software.vercel.app/';
  static const _whatsappNumber = '+59162994685';

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(_website);
    try {
      var launched = await launchUrl(uri, mode: LaunchMode.externalApplication)
          .catchError((e) {
            debugPrint('launchUrl externalApplication error: $e');
            return false;
          });

      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault)
            .catchError((e) {
              debugPrint('launchUrl platformDefault error: $e');
              return false;
            });
      }

      if (!launched && context.mounted) {
        await _showManualLinkDialog(context, _website, 'Abrir sitio web');
      }
    } catch (e) {
      debugPrint('AboutScreen._openWebsite error: $e');
      if (context.mounted) {
        await _showManualLinkDialog(context, _website, 'Abrir sitio web');
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final phone = _whatsappNumber.replaceAll('+', '');
    final webUri = Uri.parse('https://api.whatsapp.com/send?phone=$phone');
    final waUri = Uri.parse('whatsapp://send?phone=$phone');

    var launched = false;
    try {
      launched = await launchUrl(waUri, mode: LaunchMode.externalApplication)
          .catchError((e) {
            debugPrint('launchUrl whatsapp:// error: $e');
            return false;
          });
    } catch (e) {
      debugPrint('whatsapp native scheme error: $e');
    }

    if (!launched) {
      try {
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication)
            .catchError((e) {
              debugPrint('launchUrl web whatsapp error: $e');
              return false;
            });
      } catch (e) {
        debugPrint('web whatsapp launch error: $e');
      }
    }

    if (!launched && context.mounted) {
      await _showManualLinkDialog(context, webUri.toString(), 'Abrir WhatsApp');
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
              'No se pudo abrir automaticamente. Copia el enlace y pegalo en tu navegador o app:',
            ),
            const SizedBox(height: 12),
            SelectableText(url),
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
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
              }
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
      appBar: AppBar(title: const Text('Acerca de')),
      body: AppScaffoldSurface(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.spa_rounded,
                        color: cs.onPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Control Estetica',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppBadge(
                      label: 'Version 1.0.0',
                      icon: Icons.info_outline_rounded,
                      tone: AppBadgeTone.neutral,
                    ),
                    const SizedBox(height: 18),
                    Divider(color: cs.outlineVariant, height: 1),
                    const SizedBox(height: 18),
                    Text(
                      'DESARROLLADO POR',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KeyBusy Software',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Creamos soluciones digitales intuitivas para potenciar tu negocio de estetica.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _openWebsite(context),
                icon: const Icon(Icons.public_rounded),
                label: const Text('Visitar sitio web'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openWhatsApp(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Contactar por WhatsApp'),
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      Icons.copyright_rounded,
                      color: cs.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '2026 KeyBusy Software',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
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
