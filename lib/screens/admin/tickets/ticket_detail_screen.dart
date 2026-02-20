import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_estetica/repositories/ticket_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_estetica/services/share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:app_estetica/providers/ticket_provider.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  // Usar el TicketRepository inyectado por Provider cuando sea necesario
  final GlobalKey _ticketKey = GlobalKey();
  bool isUpdating = false;
  bool localeReady = false;
  bool _isEmployee = false;
  Map<String, dynamic>? _detailedTicket;
  bool _loadingDetail = false;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _loadUserType();
    _loadDetailedTicketIfNeeded();
    initializeDateFormatting('es').then((_) {
      setState(() {
        localeReady = true;
      });
    });
  }

  Future<void> _loadUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType');
      setState(() {
        _isEmployee = userType == 'empleado';
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error cargando tipo de usuario: $e');
    }
  }

  Future<void> _loadDetailedTicketIfNeeded() async {
    // Si el widget.ticket ya tiene el teléfono y sesiones completas, no es necesario recargar.
    try {
      final cliente = widget.ticket['cliente'] as Map<String, dynamic>?;
      final sesiones = widget.ticket['sesiones'] as List<dynamic>?;
      final hasPhone =
          cliente != null &&
          (cliente['telefono'] != null &&
              cliente['telefono'].toString().trim().isNotEmpty);
      final hasSesiones = sesiones != null && sesiones.isNotEmpty;

      // Si falta telefono o sesiones, cargar detalle completo desde la API
      if (!hasPhone || !hasSesiones) {
        setState(() {
          _loadingDetail = true;
          _detailError = null;
        });

        final id =
            widget.ticket['id']?.toString() ??
            widget.ticket['documentId']?.toString();
        if (id != null) {
          try {
            final repo = Provider.of<TicketRepository>(context, listen: false);
            final resp = await repo.obtenerTicketDetalle(id.toString());
            if (resp != null) {
              setState(() {
                _detailedTicket = resp;
              });
            }
          } catch (e) {
            // No fatal: guardamos el error para mostrar si es necesario
            setState(() {
              _detailError = e.toString();
            });
            if (kDebugMode)
              debugPrint('Error cargando detalle completo del ticket: $e');
          }
        }

        setState(() {
          _loadingDetail = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error en _loadDetailedTicketIfNeeded: $e');
    }
  }

  // Label legible para el método de pago
  String _labelForMetodo(String? metodo) {
    if (metodo == null) return '-';
    switch (metodo) {
      case 'efectivo':
        return 'Efectivo';
      case 'qr':
        return 'QR';
      default:
        return metodo;
    }
  }

  Future<void> _eliminarTicket() async {
    // Mostrar diálogo de confirmación
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: Colors.red,
          ),
          title: const Text('¿Eliminar ticket?'),
          content: const Text(
            'Esta acción no se puede deshacer. ¿Está seguro de que desea eliminar este ticket?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmacion != true) return;

    setState(() {
      isUpdating = true;
    });

    try {
      final documentId = widget.ticket['documentId'] ?? widget.ticket['id'];
      final success = await Provider.of<TicketProvider>(
        context,
        listen: false,
      ).deleteTicket(documentId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Ticket eliminado correctamente'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Regresar a la pantalla anterior
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Error al eliminar el ticket'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  // Construye el texto del ticket (sin lanzar)
  String _buildWhatsAppMessage() {
    final ticket = _detailedTicket ?? widget.ticket;
    final cliente = ticket['cliente'];
    final nombreCliente = cliente?['nombrecliente'] ?? 'Cliente';
    final sesiones = ticket['sesiones'] as List<dynamic>? ?? [];

    // Total del ticket
    final total = (ticket['monto_total'] as num?)?.toDouble() ?? 0.0;
    final saldo = (ticket['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;

    final buffer = StringBuffer();
    buffer.writeln('Hola *$nombreCliente*,'); // Negrita en WhatsApp
    buffer.writeln('Le enviamos el detalle de sus citas programadas:');
    buffer.writeln('');

    if (sesiones.isNotEmpty) {
      // Ordenar por fecha para que se vea bonito
      final sesionesCopia = List<dynamic>.from(sesiones);
      sesionesCopia.sort((a, b) {
        final dateA = a['fecha_hora_inicio'] ?? '9999-12-31';
        final dateB = b['fecha_hora_inicio'] ?? '9999-12-31';
        return dateA.toString().compareTo(dateB.toString());
      });

      for (var s in sesionesCopia) {
        final trat = s['tratamiento']?['nombretratamiento'] ?? 'Tratamiento';
        final num = s['numero_sesion'];

        String fechaStr = 'Fecha por definir';
        if (s['fecha_hora_inicio'] != null) {
          final dt = DateTime.parse(s['fecha_hora_inicio']);
          fechaStr = DateFormat('dd/MM - HH:mm', 'es').format(dt);
        }

        buffer.writeln('🗓 *$fechaStr*');
        buffer.writeln('   $trat (Sesión $num)');
        buffer.writeln('');
      }
    } else {
      buffer.writeln('(Sin sesiones agendadas)');
    }

    buffer.writeln('💰 *Total:* Bs ${total.toStringAsFixed(2)}');
    if (saldo > 0) {
      buffer.writeln('⚠️ *Saldo Pendiente:* Bs ${saldo.toStringAsFixed(2)}');
    }

    buffer.writeln('');
    buffer.writeln('¡Le esperamos! 💆‍♀️✨');

    return buffer.toString();
  }

  Future<void> _chooseAndSendToWhatsApp() async {
    // Seleccionar formato (texto o PDF)
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.text_snippet),
                title: const Text('Enviar como texto'),
                onTap: () => Navigator.of(context).pop('text'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Enviar como PDF'),
                onTap: () => Navigator.of(context).pop('pdf'),
              ),
            ],
          ),
        );
      },
    );

    if (format == null) return;

    // Preferir el detalle completo si está disponible
    final ticket = _detailedTicket ?? widget.ticket;
    final cliente = ticket['cliente'];
    final telefonoRaw = (cliente != null)
        ? (cliente['telefono']?.toString() ?? cliente['phone']?.toString())
        : null;
    String digits = telefonoRaw != null
        ? telefonoRaw.replaceAll(RegExp(r'[^0-9]'), '')
        : '';
    if (digits.isEmpty) {
      // Forzar carga del detalle si no lo hemos cargado aún
      await _loadDetailedTicketIfNeeded();

      final ticket2 = _detailedTicket ?? widget.ticket;
      final cliente2 = ticket2['cliente'];
      final telefonoRaw2 = (cliente2 != null)
          ? (cliente2['telefono']?.toString() ?? cliente2['phone']?.toString())
          : null;
      digits = telefonoRaw2 != null
          ? telefonoRaw2.replaceAll(RegExp(r'[^0-9]'), '')
          : '';

      if (digits.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El cliente no tiene teléfono')),
          );
        return;
      }
    }
    if (digits.length <= 8) digits = '591$digits';

    final message = _buildWhatsAppMessage();

    // Elegir app (WhatsApp o WhatsApp Business)
    final appChoice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
                title: const Text('WhatsApp'),
                onTap: () => Navigator.of(context).pop('com.whatsapp'),
              ),
              ListTile(
                leading: const Icon(Icons.business, color: Color(0xFF25D366)),
                title: const Text('WhatsApp Business'),
                onTap: () => Navigator.of(context).pop('com.whatsapp.w4b'),
              ),
            ],
          ),
        );
      },
    );

    if (appChoice == null) return; // usuario canceló

    if (format == 'text') {
      final encoded = Uri.encodeComponent(message);
      final waUrl = Uri.parse('https://wa.me/$digits?text=$encoded');
      if (!await launchUrl(waUrl, mode: LaunchMode.externalApplication)) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
          );
      }
      return;
    }

    // Si es PDF, generarlo y enviarlo
    try {
      final ticketForPdf = _detailedTicket ?? widget.ticket;
      final pdfBytes = await ShareService.buildTicketPdf(ticketForPdf);
      final nameBase =
          (ticketForPdf['documentId'] ??
                  ticketForPdf['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString())
              .toString();
      // Intentar escribir archivo temporal. En web esto dispara la descarga y lanza UnsupportedError.
      dynamic
      file; // usar dynamic porque dart:io File no está disponible en web
      try {
        file = await ShareService.writeTempFile(
          pdfBytes,
          '${ShareService.sanitizeFileName(nameBase)}_ticket.pdf',
        );
      } on UnsupportedError catch (_) {
        // En web, writeTempFile ejecutó la descarga directa; informar al usuario y salir.
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se abrió la descarga del PDF en el navegador'),
            ),
          );
        return;
      }

      // Intentar enviar directo a WhatsApp nativo; si falla, abrir share sheet
      final sent = await ShareService.shareFileToWhatsAppNative(
        file,
        caption: message,
        package: appChoice,
        phone: digits,
      );
      if (!sent) {
        // Fallback: abrir share sheet con el archivo y el texto
        try {
          await ShareService.shareFile(file, text: message);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se abrió el selector para compartir el PDF'),
              ),
            );
        } catch (e) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo compartir el PDF: $e')),
            );
        }
      }
    } catch (e) {
      // Mostrar detalle del error y sugerir usar el texto en su lugar
      if (kDebugMode) debugPrint('Error generando o compartiendo PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error preparando archivo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Esperar a que la localización esté lista
    if (!localeReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Preferir el ticket detallado si está cargado
    final ticketData = _detailedTicket ?? widget.ticket;
    // Extraer información del ticket (estructura Supabase)
    final cliente = ticketData['cliente'];
    final sesiones = ticketData['sesiones'] as List<dynamic>? ?? [];
    final pagos = ticketData['pagos'] as List<dynamic>? ?? [];

    // Crear una copia ordenada de las sesiones: de más antiguo a más reciente.
    // Si la sesión no tiene fecha, la colocamos al final.
    final sesionesOrdenadas = List<dynamic>.from(sesiones);
    sesionesOrdenadas.sort((a, b) {
      try {
        final fa = a?['fecha_hora_inicio'];
        final fb = b?['fecha_hora_inicio'];
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1; // a sin fecha => va al final
        if (fb == null) return -1; // b sin fecha => a antes
        final da = DateTime.parse(fa.toString());
        final db = DateTime.parse(fb.toString());
        return da.compareTo(db); // ascendente
      } catch (e) {
        return 0;
      }
    });

    final montoTotal = (ticketData['monto_total'] as num?)?.toDouble() ?? 0.0;
    final montoPagado = (ticketData['monto_pagado'] as num?)?.toDouble() ?? 0.0;
    final saldoPendiente =
        (ticketData['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
    final estadoPago = ticketData['estado_pago'] ?? '-';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Detalle del Ticket'),
        elevation: 0,
        actions: [
          // Botón para eliminar ticket (solo visible para administradores)
          if (!_isEmployee)
            IconButton(
              onPressed: isUpdating ? null : _eliminarTicket,
              tooltip: 'Eliminar ticket',
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
            ),
          // Botón único para enviar ticket por WhatsApp (texto o PDF)
          IconButton(
            onPressed: _chooseAndSendToWhatsApp,
            tooltip: 'Enviar ticket por WhatsApp',
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _ticketKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mostrar error de detalle si existe
              if (_detailError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    color: Colors.orange.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Error cargando detalle: ${_detailError}',
                              style: textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Cliente
              _SectionCard(
                title: 'Cliente',
                icon: Icons.person,
                children: [
                  _DetailRow(
                    label: 'Nombre',
                    value: cliente != null
                        ? '${cliente['nombrecliente'] ?? ''} ${cliente['apellidocliente'] ?? ''}'
                        : '-',
                  ),
                  if (cliente != null &&
                      ((cliente['telefono'] != null &&
                              cliente['telefono'].toString().isNotEmpty) ||
                          (cliente['phone'] != null &&
                              cliente['phone'].toString().isNotEmpty)))
                    _DetailRow(
                      label: 'Teléfono',
                      value: (cliente['telefono'] ?? cliente['phone'])
                          .toString(),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              _SectionCard(
                title: 'Agenda de Sesiones',
                icon: Icons.calendar_month,
                children: [
                  if (sesiones.isEmpty)
                    const _DetailRow(
                      label: 'Estado',
                      value: 'Sin sesiones registradas',
                    )
                  else
                    ...sesionesOrdenadas.asMap().entries.map((entry) {
                      final index = entry.key;
                      final s = entry.value;

                      // 1. Extraer Tratamiento
                      final tratamiento = s['tratamiento'];
                      final nombreTratamiento = tratamiento != null
                          ? (tratamiento['nombretratamiento'] ?? 'Tratamiento')
                          : 'Tratamiento';

                      final numSesion = s['numero_sesion'] ?? 0;

                      final estadoRaw =
                          s['estado_sesion'] ??
                          s['estado_sesion'] ??
                          'agendada';
                      final estadoStr = estadoRaw
                          .toString()
                          .toLowerCase(); // Normalizamos a minúscula

                      // Verificamos si está realizada (aceptamos 'realizada', 'completada', etc.)
                      final isRealizada =
                          estadoStr == 'realizada' || estadoStr == 'completada';

                      // 3. Extraer Fecha y Hora
                      final fechaRaw = s['fecha_hora_inicio'];
                      String fechaFormateada = 'Sin agendar';

                      if (fechaRaw != null) {
                        // Parseamos la fecha ISO de Supabase
                        final dt = DateTime.parse(fechaRaw.toString());
                        // Formato amigable: "25/01/2026 • 14:30"
                        fechaFormateada = DateFormat(
                          'dd/MM/yyyy • HH:mm',
                          'es',
                        ).format(dt);
                      }

                      return Container(
                        margin: EdgeInsets.only(
                          bottom: index < sesionesOrdenadas.length - 1 ? 12 : 0,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // Fondo verde suave si está realizada, gris si no
                          color: isRealizada
                              ? Colors.green.withValues(alpha: 0.05)
                              : colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.3,
                                ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRealizada
                                ? Colors.green.withValues(alpha: 0.3)
                                : colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Columna Izquierda: Icono y Número
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isRealizada
                                      ? Colors.green
                                      : colorScheme.primary,
                                  child: Icon(
                                    isRealizada
                                        ? Icons.check
                                        : Icons.access_time,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '#$numSesion',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Columna Central: Detalles
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombreTratamiento,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event,
                                        size: 14,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        fechaFormateada,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Badge de Estado
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isRealizada
                                          ? Colors.green
                                          : Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isRealizada ? 'REALIZADA' : 'PENDIENTE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
              const SizedBox(height: 16),

              // Información de pago
              _SectionCard(
                title: 'Información de Pago',
                icon: Icons.payments,
                children: [
                  _DetailRow(
                    label: 'Total',
                    value: 'Bs ${montoTotal.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Pagado',
                    value: 'Bs ${montoPagado.toStringAsFixed(2)}',
                  ),
                  _DetailRow(
                    label: 'Saldo pendiente',
                    value: 'Bs ${saldoPendiente.toStringAsFixed(2)}',
                    valueColor: saldoPendiente > 0 ? colorScheme.error : null,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: estadoPago == 'pagado'
                          ? colorScheme.primaryContainer
                          : colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          estadoPago == 'pagado'
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_outlined,
                          size: 20,
                          color: estadoPago == 'pagado'
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Estado: $estadoPago',
                          style: textTheme.titleSmall?.copyWith(
                            color: estadoPago == 'pagado'
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (pagos.isNotEmpty)
                _SectionCard(
                  title: 'Pagos',
                  icon: Icons.payments,
                  children: [
                    ...pagos.map((p) {
                      final monto = (p['monto'] as num?)?.toDouble() ?? 0.0;
                      final metodo = p['metodo_pago']?.toString();
                      String fechaStr = '-';
                      try {
                        final raw = p['fecha_pago'] ?? p['created_at'];
                        final dt = raw is DateTime
                            ? raw
                            : DateTime.tryParse(raw.toString());
                        if (dt != null)
                          fechaStr = DateFormat(
                            'dd MMM, HH:mm',
                            'es',
                          ).format(dt);
                      } catch (_) {}

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bs ${monto.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$fechaStr • ${_labelForMetodo(metodo)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox.shrink(),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),

              // Botón de acción - Enviar por WhatsApp (deshabilitado si loading)
              SizedBox(
                width: double.infinity,
                child: _loadingDetail
                    ? FilledButton.icon(
                        onPressed: null,
                        icon: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: const Text('Cargando...'),
                      )
                    : FilledButton.icon(
                        onPressed: _chooseAndSendToWhatsApp,
                        icon: const Icon(Icons.send, color: Colors.white),
                        label: const Text('Enviar por WhatsApp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF25D366,
                          ), // Verde de WhatsApp
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: textTheme.bodyLarge?.copyWith(
                color: valueColor ?? colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
