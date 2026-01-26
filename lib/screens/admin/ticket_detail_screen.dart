import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_estetica/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_estetica/services/share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final ApiService api = ApiService();
  final GlobalKey _ticketKey = GlobalKey();
  bool isUpdating = false;
  bool localeReady = false;
  bool _isEmployee = false;

  @override
  void initState() {
    super.initState();
    _loadUserType();
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
      print('Error cargando tipo de usuario: $e');
    }
  }

  String? _getCategoriaNombreFromTratamiento(dynamic tratamiento) {
    final possibleKeys = [
      'categoria_tratamiento',
      'categoria-tratamiento',
      'categoriaTratamiento',
      'categoria',
      'categoria_tratamientos',
      'categoriaTratamientos'
    ];

    for (final key in possibleKeys) {
      final catValue = tratamiento[key];
      if (catValue != null && catValue is Map) {
        final nombre = catValue['nombreCategoria'] ?? catValue['nombre'];
        if (nombre != null) return nombre as String;
      }
    }
    return null;
  }

  Future<void> _marcarComoAtendido() async {
    setState(() {
      isUpdating = true;
    });

    try {
      // Usar 'id' de Supabase en lugar de 'documentId' de Strapi
      final ticketId = widget.ticket['id'];

      if (ticketId == null) {
        throw Exception('ID de ticket no encontrado');
      }

      final success = await api.actualizarEstadoTicket(ticketId.toString(), true);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket marcado como atendido'),
            backgroundColor: Colors.green,
          ),
        );
        // Regresar a la pantalla anterior con resultado
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al actualizar el ticket'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
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

  Future<void> _eliminarTicket() async {
    // Mostrar diálogo de confirmación
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
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
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
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
      final documentId = widget.ticket['documentId'];
      final success = await api.eliminarTicket(documentId);

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
    final cliente = widget.ticket['cliente'];
    final createdAt = widget.ticket['created_at'] != null ? DateTime.tryParse(widget.ticket['created_at']) : null;
    final nombreCliente = cliente?['nombrecliente'] ?? '';
    final apellidoCliente = cliente?['apellidocliente'] ?? '';
    final sesiones = widget.ticket['sesiones'] as List<dynamic>? ?? [];

    // Extraer tratamientos únicos de las sesiones
    final Map<int, Map<String, dynamic>> tratamientosMap = {};
    for (var sesion in sesiones) {
      final tratamiento = sesion['tratamiento'];
      if (tratamiento != null) {
        final tratId = tratamiento['id'];
        if (tratId != null && !tratamientosMap.containsKey(tratId)) {
          tratamientosMap[tratId] = tratamiento;
        }
      }
    }
    final tratamientos = tratamientosMap.values.toList();

    final buffer = StringBuffer();
    buffer.writeln('Hola $nombreCliente $apellidoCliente,');
    buffer.writeln('Aquí están los detalles de su turno:');

    if (createdAt != null) {
      buffer.writeln('- Fecha de venta: ${DateFormat('EEEE, d MMMM yyyy', 'es').format(createdAt)}');
      buffer.writeln('- Hora: ${DateFormat('HH:mm').format(createdAt)}');
    }

    buffer.writeln('- Ticket: ${widget.ticket['id']}');

    if (tratamientos.isNotEmpty) {
      buffer.writeln('- Tratamientos:');
      for (final t in tratamientos) {
        final nombre = t['nombretratamiento'] ?? 'Sin nombre';
        final precio = t['precio'] ?? '0';
        buffer.writeln('  • $nombre - Bs $precio');
      }
    }

    final montoTotal = widget.ticket['monto_total'] ?? 0;
    buffer.writeln('- Total: Bs ${montoTotal.toStringAsFixed(2)}');
    buffer.writeln('Por favor confirme su asistencia o contáctenos si necesita reprogramar.');

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

    final cliente = widget.ticket['cliente'];
    final telefonoRaw = cliente?['telefono']?.toString();
    String digits = telefonoRaw != null ? telefonoRaw.replaceAll(RegExp(r'[^0-9]'), '') : '';
    if (digits.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El cliente no tiene teléfono')));
      return;
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
                leading: Image.asset('assets/whatsapp.png', width: 28, height: 28, errorBuilder: (_, __, ___) => Icon(Icons.chat)),
                title: const Text('WhatsApp'),
                onTap: () => Navigator.of(context).pop('com.whatsapp'),
              ),
              ListTile(
                leading: Image.asset('assets/whatsapp_business.png', width: 28, height: 28, errorBuilder: (_, __, ___) => Icon(Icons.business)),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp')));
      }
      return;
    }

    // Si es PDF, generarlo y enviarlo
    try {
      final pdfBytes = await ShareService.buildTicketPdf(widget.ticket);
      final nameBase = (widget.ticket['documentId'] ?? widget.ticket['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();
      final file = await ShareService.writeTempFile(pdfBytes, '${ShareService.sanitizeFileName(nameBase)}_ticket.pdf');
      final sent = await ShareService.shareFileToWhatsAppNative(file, caption: message, package: appChoice, phone: digits);
      if (!sent) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo enviar directamente a la app seleccionada, se abrió el share sheet.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error preparando archivo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Esperar a que la localización esté lista
    if (!localeReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Extraer información del ticket (estructura Supabase)
    final createdAt = widget.ticket['created_at'] != null
        ? DateTime.parse(widget.ticket['created_at'])
        : null;
    final cliente = widget.ticket['cliente'];
    final sesiones = widget.ticket['sesiones'] as List<dynamic>? ?? [];

    // Extraer tratamientos únicos de las sesiones
    final Map<int, Map<String, dynamic>> tratamientosMap = {};
    for (var sesion in sesiones) {
      final tratamiento = sesion['tratamiento'];
      if (tratamiento != null) {
        final tratId = tratamiento['id'];
        if (tratId != null && !tratamientosMap.containsKey(tratId)) {
          tratamientosMap[tratId] = tratamiento;
        }
      }
    }
    final tratamientos = tratamientosMap.values.toList();

    final montoTotal = (widget.ticket['monto_total'] as num?)?.toDouble() ?? 0.0;
    final montoPagado = (widget.ticket['monto_pagado'] as num?)?.toDouble() ?? 0.0;
    final saldoPendiente = (widget.ticket['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
    final estadoPago = widget.ticket['estado_pago'] ?? '-';
    final estadoTicket = widget.ticket['estadoTicket'] == true;


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
            icon: Image.asset(
              'assets/whatsapp.png',
              width: 24,
              height: 24,
              errorBuilder: (_, __, ___) => const Icon(Icons.send),
            ),
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
                  if (cliente?['telefono'] != null)
                    _DetailRow(
                      label: 'Teléfono',
                      value: cliente['telefono'].toString(),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Tratamientos (ahora puede haber múltiples)
              _SectionCard(
                title: 'Tratamientos',
                icon: Icons.spa,
                children: [
                  if (tratamientos.isEmpty)
                    const _DetailRow(
                      label: 'Servicios',
                      value: 'Sin tratamientos',
                    )
                  else
                    ...tratamientos.asMap().entries.map((entry) {
                      final index = entry.key;
                      final t = entry.value;
                      final categoriaNombre = _getCategoriaNombreFromTratamiento(t);

                      return Padding(
                        padding: EdgeInsets.only(bottom: index < tratamientos.length - 1 ? 12 : 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t['nombretratamiento'] ?? 'Sin nombre',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (categoriaNombre != null) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.category,
                                                size: 12,
                                                color: colorScheme.primary.withValues(alpha: 0.7),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                categoriaNombre,
                                                style: textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.primary.withValues(alpha: 0.7),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Bs ${t['precio'] ?? '0'}',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  if (tratamientos.length > 1) ...[
                    const SizedBox(height: 12),
                    Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
                    const SizedBox(height: 8),
                    _DetailRow(
                      label: 'Total de tratamientos',
                      value: 'Bs ${montoTotal.toStringAsFixed(2)}',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Sesiones programadas
              _SectionCard(
                title: 'Sesiones',
                icon: Icons.event_note,
                children: [
                  if (sesiones.isEmpty)
                    const _DetailRow(
                      label: 'Estado',
                      value: 'Sin sesiones programadas',
                    )
                  else ...[
                    // Mostrar resumen de sesiones por tratamiento
                    ...tratamientos.asMap().entries.map((entry) {
                      final index = entry.key;
                      final trat = entry.value;
                      final tratId = trat['id'];

                      // Filtrar sesiones de este tratamiento
                      final sesionesTratamiento = sesiones.where((s) {
                        final tratamiento = s['tratamiento'];
                        return tratamiento != null && tratamiento['id'] == tratId;
                      }).toList();

                      final totalSesiones = sesionesTratamiento.length;
                      final sesionesRealizadas = sesionesTratamiento.where((s) =>
                        s['estado_sesion_enum'] == 'realizada'
                      ).length;
                      final sesionesPendientes = totalSesiones - sesionesRealizadas;

                      return Padding(
                        padding: EdgeInsets.only(bottom: index < tratamientos.length - 1 ? 16 : 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      trat['nombretratamiento'] ?? 'Sin nombre',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$totalSesiones ${totalSesiones == 1 ? 'sesión' : 'sesiones'}',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Realizadas: $sesionesRealizadas',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.pending, size: 16, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pendientes: $sesionesPendientes',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Fecha y hora
              _SectionCard(
                title: 'Fecha y Hora',
                icon: Icons.calendar_today,
                children: [
                  _DetailRow(
                    label: 'Fecha',
                    value: createdAt != null
                        ? DateFormat('EEEE, d MMMM yyyy', 'es').format(createdAt)
                        : '-',
                  ),
                  _DetailRow(
                    label: 'Hora',
                    value: createdAt != null ? DateFormat('HH:mm').format(createdAt) : '-',
                  ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

              // Botón de acción - Enviar por WhatsApp
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _chooseAndSendToWhatsApp,
                  icon: Image.asset(
                    'assets/whatsapp.png',
                    width: 24,
                    height: 24,
                    color: Colors.white,
                    errorBuilder: (_, __, ___) => const Icon(Icons.send, color: Colors.white),
                  ),
                  label: const Text('Enviar por WhatsApp'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // Verde de WhatsApp
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

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

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

