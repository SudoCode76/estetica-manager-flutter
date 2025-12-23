import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/new_ticket_screen.dart';
import 'package:app_estetica/services/api_service.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({Key? key}) : super(key: key);

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ApiService api = ApiService();
  List<dynamic> tickets = [];
  List<dynamic> filteredTickets = [];
  List<dynamic> sucursales = [];
  int? selectedSucursalId;
  bool isLoading = true;
  String search = '';
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    fetchSucursalesAndTickets();
  }

  Future<void> fetchSucursalesAndTickets() async {
    setState(() { isLoading = true; errorMsg = null; });
    try {
      sucursales = await api.getSucursales();
      if (sucursales.isNotEmpty) {
        selectedSucursalId = sucursales.first['id'];
      }
      await fetchTickets();
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
      setState(() { isLoading = false; });
    }
  }

  Future<void> fetchTickets() async {
    setState(() { isLoading = true; errorMsg = null; });
    try {
      final data = await api.getTickets(sucursalId: selectedSucursalId);
      tickets = data;
      filteredTickets = tickets;
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
    }
    setState(() { isLoading = false; });
  }

  void filterTickets(String value) {
    setState(() {
      search = value;
      filteredTickets = tickets.where((t) {
        final cliente = t['attributes']?['cliente']?['data']?['attributes']?['nombreCliente'] ?? '';
        final tratamiento = t['attributes']?['tratamiento']?['data']?['attributes']?['nombreTratamiento'] ?? '';
        return cliente.toLowerCase().contains(value.toLowerCase()) ||
               tratamiento.toLowerCase().contains(value.toLowerCase());
      }).toList();
    });
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white60, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fondo gradiente profesional
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1a1a2e),
                Color(0xFF16213e),
                Color(0xFF0f3460),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: filterTickets,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Buscar por cliente o tratamiento',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF00d4ff), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00d4ff).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00d4ff).withValues(alpha: 0.3)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh),
                        color: const Color(0xFF00d4ff),
                        onPressed: fetchTickets,
                        tooltip: 'Actualizar',
                      ),
                    ),
                  ],
                ),
              ),
              // Filtro de sucursal
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: const Color(0xFF00d4ff), size: 22),
                      const SizedBox(width: 12),
                      const Text(
                        'Sucursal:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedSucursalId,
                            dropdownColor: const Color(0xFF1a1a2e),
                            iconEnabledColor: const Color(0xFF00d4ff),
                            isExpanded: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            items: sucursales.map((s) {
                              return DropdownMenuItem<int>(
                                value: s['id'],
                                child: Text(s['nombreSucursal'] ?? '-'),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              setState(() { selectedSucursalId = value; });
                              await fetchTickets();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMsg != null
                        ? Center(child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                        : filteredTickets.isEmpty
                            ? const Center(child: Text('No hay tickets registrados', style: TextStyle(color: Colors.white70)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: filteredTickets.length,
                                itemBuilder: (context, i) {
                                  final t = filteredTickets[i];
                                  final fecha = t['fecha'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(t['fecha'])) : '-';
                                  final cliente = t['cliente'] != null
                                      ? ((t['cliente']['apellidoCliente'] ?? '').isNotEmpty
                                          ? '${t['cliente']['nombreCliente'] ?? '-'} ${t['cliente']['apellidoCliente'] ?? ''}'
                                          : t['cliente']['nombreCliente'] ?? '-')
                                      : '-';
                                  final tratamiento = t['tratamiento']?['nombreTratamiento'] ?? '-';
                                  final cuota = t['cuota']?.toString() ?? '-';
                                  final saldo = t['saldoPendiente']?.toString() ?? '-';
                                  final estadoPago = t['estadoPago'] ?? '-';
                                  final estadoTicket = t['estadoTicket'] == true;
                                  final sucursalNombre = t['sucursal']?['nombreSucursal'] ?? '-';

                                  // Color según estado de pago
                                  Color estadoColor = estadoPago == 'Completo'
                                      ? const Color(0xFF00d4aa)
                                      : const Color(0xFFff6b6b);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withValues(alpha: 0.15),
                                                Colors.white.withValues(alpha: 0.05),
                                              ],
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Header con cliente y estado
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                        color: estadoTicket
                                                            ? const Color(0xFF00d4aa).withValues(alpha: 0.2)
                                                            : const Color(0xFFff6b6b).withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: estadoTicket
                                                              ? const Color(0xFF00d4aa)
                                                              : const Color(0xFFff6b6b),
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        estadoTicket ? Icons.check_circle : Icons.cancel,
                                                        color: estadoTicket
                                                            ? const Color(0xFF00d4aa)
                                                            : const Color(0xFFff6b6b),
                                                        size: 24,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            cliente,
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.bold,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            tratamiento,
                                                            style: TextStyle(
                                                              color: const Color(0xFF00d4ff),
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF00d4ff).withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: IconButton(
                                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                                        color: const Color(0xFF00d4ff),
                                                        onPressed: () {
                                                          // TODO: Editar ticket
                                                        },
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                const Divider(
                                                  color: Colors.white24,
                                                  thickness: 1,
                                                ),
                                                const SizedBox(height: 12),
                                                // Información detallada
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildInfoItem(
                                                        Icons.location_on_outlined,
                                                        'Sucursal',
                                                        sucursalNombre,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: _buildInfoItem(
                                                        Icons.calendar_today_outlined,
                                                        'Fecha',
                                                        fecha,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildInfoItem(
                                                        Icons.payments_outlined,
                                                        'Cuota',
                                                        'Bs $cuota',
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: _buildInfoItem(
                                                        Icons.account_balance_wallet_outlined,
                                                        'Saldo',
                                                        'Bs $saldo',
                                                        valueColor: saldo != '0' ? const Color(0xFFff6b6b) : const Color(0xFF00d4aa),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                // Estado de pago destacado
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: estadoColor.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(
                                                      color: estadoColor.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        estadoPago == 'Completo'
                                                            ? Icons.check_circle_outline
                                                            : Icons.warning_amber_outlined,
                                                        color: estadoColor,
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Estado: $estadoPago',
                                                        style: TextStyle(
                                                          color: estadoColor,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 32,
          right: 32,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00d4ff), Color(0xFF0099cc)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00d4ff).withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewTicketScreen()),
                );
                if (result == true) fetchTickets();
              },
              icon: const Icon(Icons.add, size: 24),
              label: const Text(
                'Nuevo Ticket',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
