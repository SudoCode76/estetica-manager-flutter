import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:app_estetica/screens/admin/new_ticket_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({Key? key}) : super(key: key);

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List<dynamic> tickets = [];
  List<dynamic> filteredTickets = [];
  bool isLoading = true;
  String search = '';
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    setState(() { isLoading = true; errorMsg = null; });
    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:1337/api/tickets'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        tickets = data['data'];
        filteredTickets = tickets;
      } else {
        errorMsg = 'Error al obtener tickets: ${response.statusCode}';
      }
    } catch (e) {
      errorMsg = 'No se pudo conectar al servidor.';
    }
    setState(() { isLoading = false; });
  }

  void filterTickets(String value) {
    setState(() {
      search = value;
      filteredTickets = tickets.where((t) {
        final cliente = t['cliente']?['nombreCliente'] ?? '';
        final tratamiento = t['tratamiento']?['nombreTratamiento'] ?? '';
        return cliente.toLowerCase().contains(value.toLowerCase()) ||
               tratamiento.toLowerCase().contains(value.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fondo gradiente
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
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
                      child: TextField(
                        onChanged: filterTickets,
                        decoration: InputDecoration(
                          hintText: 'Buscar por cliente o tratamiento',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      color: Colors.white,
                      onPressed: fetchTickets,
                      tooltip: 'Actualizar',
                    ),
                  ],
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
                                  final cliente = t['cliente']?['nombreCliente'] ?? '-';
                                  final tratamiento = t['tratamiento']?['nombreTratamiento'] ?? '-';
                                  final cuota = t['cuota']?.toString() ?? '-';
                                  final saldo = t['saldoPendiente']?.toString() ?? '-';
                                  final estadoPago = t['estadoPago'] ?? '-';
                                  final estadoTicket = t['estadoTicket'] == true;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(22),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withValues(alpha: 0.22),
                                                Colors.white.withValues(alpha: 0.10),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.10),
                                                blurRadius: 18,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: estadoTicket ? Colors.green : Colors.red,
                                              child: Icon(
                                                estadoTicket ? Icons.check : Icons.close,
                                                color: Colors.white,
                                              ),
                                            ),
                                            title: Text('$cliente - $tratamiento', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Fecha: $fecha'),
                                                Text('Cuota: Bs $cuota'),
                                                Text('Saldo: Bs $saldo'),
                                                Text('Estado de pago: $estadoPago'),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.edit, color: Color(0xFF667eea)),
                                              onPressed: () {
                                                // TODO: Editar ticket
                                              },
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
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewTicketScreen()),
              );
              if (result == true) fetchTickets();
            },
            icon: const Icon(Icons.add),
            label: const Text('Nuevo Ticket'),
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            elevation: 10,
          ),
        ),
      ],
    );
  }
}
