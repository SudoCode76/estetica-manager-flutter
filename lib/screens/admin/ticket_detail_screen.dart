import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_estetica/services/api_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final ApiService api = ApiService();
  bool isUpdating = false;
  bool localeReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es').then((_) {
      setState(() {
        localeReady = true;
      });
    });
  }

  Future<void> _marcarComoAtendido() async {
    setState(() { isUpdating = true; });

    try {
      final documentId = widget.ticket['documentId'];
      final success = await api.actualizarEstadoTicket(documentId, true);

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
        setState(() { isUpdating = false; });
      }
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

    // Extraer información del ticket
    final fecha = widget.ticket['fecha'] != null
        ? DateTime.parse(widget.ticket['fecha'])
        : null;
    final cliente = widget.ticket['cliente'];
    final tratamiento = widget.ticket['tratamiento'];
    final sucursal = widget.ticket['sucursal'];
    final cuota = widget.ticket['cuota']?.toString() ?? '-';
    final saldo = widget.ticket['saldoPendiente']?.toString() ?? '0';
    final estadoPago = widget.ticket['estadoPago'] ?? '-';
    final estadoTicket = widget.ticket['estadoTicket'] == true;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Detalle del Ticket'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              // TODO: Editar ticket
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función de edición próximamente')),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado del ticket
            Card(
              elevation: 0,
              color: estadoTicket
                  ? colorScheme.primaryContainer
                  : colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      estadoTicket ? Icons.check_circle : Icons.pending_actions,
                      color: estadoTicket
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onErrorContainer,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            estadoTicket ? 'Atendido' : 'Pendiente',
                            style: textTheme.headlineSmall?.copyWith(
                              color: estadoTicket
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            estadoTicket
                                ? 'Este ticket ya fue atendido'
                                : 'Este ticket está pendiente de atención',
                            style: textTheme.bodyMedium?.copyWith(
                              color: estadoTicket
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Cliente
            _SectionCard(
              title: 'Cliente',
              icon: Icons.person,
              children: [
                _DetailRow(
                  label: 'Nombre',
                  value: cliente != null
                      ? '${cliente['nombreCliente'] ?? ''} ${cliente['apellidoCliente'] ?? ''}'
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

            // Tratamiento
            _SectionCard(
              title: 'Tratamiento',
              icon: Icons.spa,
              children: [
                _DetailRow(
                  label: 'Servicio',
                  value: tratamiento?['nombreTratamiento'] ?? '-',
                ),
                _DetailRow(
                  label: 'Precio del tratamiento',
                  value: tratamiento?['precio'] != null
                      ? 'Bs ${tratamiento['precio']}'
                      : '-',
                ),
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
                  value: fecha != null
                      ? DateFormat('EEEE, d MMMM yyyy', 'es').format(fecha)
                      : '-',
                ),
                _DetailRow(
                  label: 'Hora',
                  value: fecha != null ? DateFormat('HH:mm').format(fecha) : '-',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sucursal
            _SectionCard(
              title: 'Sucursal',
              icon: Icons.location_on,
              children: [
                _DetailRow(
                  label: 'Nombre',
                  value: sucursal?['nombreSucursal'] ?? '-',
                ),
                if (sucursal?['direccion'] != null)
                  _DetailRow(
                    label: 'Dirección',
                    value: sucursal['direccion'],
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
                  label: 'Cuota pagada',
                  value: 'Bs $cuota',
                ),
                _DetailRow(
                  label: 'Saldo pendiente',
                  value: 'Bs $saldo',
                  valueColor: saldo != '0' ? colorScheme.error : null,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: estadoPago == 'Completo'
                        ? colorScheme.primaryContainer
                        : colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        estadoPago == 'Completo'
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_outlined,
                        size: 20,
                        color: estadoPago == 'Completo'
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Estado: $estadoPago',
                        style: textTheme.titleSmall?.copyWith(
                          color: estadoPago == 'Completo'
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

            // Botones de acción
            if (!estadoTicket)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isUpdating ? null : _marcarComoAtendido,
                  icon: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(isUpdating ? 'Actualizando...' : 'Marcar como Atendido'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
          ],
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

