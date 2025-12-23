import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_estetica/services/api_service.dart';

class NewTicketScreen extends StatefulWidget {
  final String? currentUserId;
  const NewTicketScreen({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final ApiService api = ApiService();
  DateTime? fecha;
  int? tratamientoId;
  int? clienteId;
  int? usuarioId;
  double? cuota;
  double? pago;
  double saldoPendiente = 0;
  String estadoPago = 'Incompleto';
  bool estadoTicket = true;

  List<dynamic> tratamientos = [];
  List<dynamic> clientes = [];
  List<dynamic> usuarios = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    setState(() { isLoading = true; });
    try {
      tratamientos = await api.getTratamientos();
      clientes = await api.getClientes();
      usuarios = await api.getUsuarios();
    } catch (e) {
      error = 'Error al cargar datos';
    }
    setState(() { isLoading = false; });
  }

  void calcularEstadoPago() {
    if (cuota != null && pago != null) {
      saldoPendiente = cuota! - pago!;
      if (saldoPendiente <= 0) {
        estadoPago = 'Completo';
        saldoPendiente = 0;
      } else {
        estadoPago = 'Incompleto';
      }
    }
  }

  Future<void> crearTicket() async {
    if (fecha == null || tratamientoId == null || clienteId == null || usuarioId == null || cuota == null || pago == null) {
      setState(() { error = 'Completa todos los campos'; });
      return;
    }
    calcularEstadoPago();
    final ticket = {
      'fecha': fecha!.toIso8601String(),
      'cuota': cuota,
      'saldoPendiente': saldoPendiente,
      'estadoTicket': estadoTicket,
      'tratamiento': tratamientoId,
      'cliente': clienteId,
      'users_permissions_user': usuarioId,
      'estadoPago': estadoPago,
    };
    final ok = await api.crearTicket(ticket);
    if (ok) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() { error = 'Error al crear ticket'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Ticket'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
              ),
            ),
          ),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Fecha
                        Text('Fecha y hora', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  fecha = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              fecha == null ? 'Seleccionar fecha y hora' : DateFormat('dd/MM/yyyy HH:mm').format(fecha!),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Tratamiento
                        Text('Tratamiento', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: tratamientoId,
                          items: tratamientos.map<DropdownMenuItem<int>>((t) {
                            final precio = double.tryParse(t['precio'] ?? '0') ?? 0;
                            return DropdownMenuItem(
                              value: t['id'],
                              child: Text('${t['nombreTratamiento']} (Bs $precio)'),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              tratamientoId = v;
                              final t = tratamientos.firstWhere((e) => e['id'] == v);
                              cuota = double.tryParse(t['precio'] ?? '0') ?? 0;
                              pago = cuota;
                              calcularEstadoPago();
                            });
                          },
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0x22FFFFFF),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                            hintText: 'Seleccionar tratamiento',
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Cliente
                        Text('Cliente', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: clienteId,
                          items: clientes.map<DropdownMenuItem<int>>((c) {
                            return DropdownMenuItem(
                              value: c['id'],
                              child: Text('${c['nombreCliente']} ${c['apellidoCliente']}'),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => clienteId = v),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0x22FFFFFF),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                            hintText: 'Seleccionar cliente',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Registrar nuevo cliente (puede abrir un dialogo o pantalla)
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Registrar nuevo cliente'),
                        ),
                        const SizedBox(height: 18),
                        // Usuario
                        Text('Usuario', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: usuarioId,
                          items: usuarios.map<DropdownMenuItem<int>>((u) {
                            return DropdownMenuItem(
                              value: u['id'],
                              child: Text(u['username'] ?? u['email'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => usuarioId = v),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0x22FFFFFF),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                            hintText: 'Seleccionar usuario',
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Pago
                        Text('Pago realizado (Bs)', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: pago?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0x22FFFFFF),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                            hintText: 'Monto pagado',
                          ),
                          onChanged: (v) {
                            setState(() {
                              pago = double.tryParse(v) ?? 0;
                              calcularEstadoPago();
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        // Estado de pago y saldo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estado de pago: $estadoPago', style: TextStyle(color: estadoPago == 'Completo' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                            Text('Saldo pendiente: Bs $saldoPendiente', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(error!, style: const TextStyle(color: Colors.red)),
                          ),
                        ElevatedButton.icon(
                          onPressed: crearTicket,
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar Ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

