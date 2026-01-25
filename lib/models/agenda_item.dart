/// Modelo para la vista de agenda diaria (sesiones programadas)
class AgendaItem {
  final String sesionId;
  final DateTime? fechaHora;
  final String nombreCliente;
  final String nombreTratamiento;
  final String estadoPago; // 'pendiente', 'pagado', 'parcial'
  final double saldoPendiente;
  final int numeroSesion;
  final String? ticketId;

  AgendaItem({
    required this.sesionId,
    this.fechaHora,
    required this.nombreCliente,
    required this.nombreTratamiento,
    required this.estadoPago,
    required this.saldoPendiente,
    required this.numeroSesion,
    this.ticketId,
  });

  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    return AgendaItem(
      sesionId: json['sesion_id']?.toString() ?? '',
      fechaHora: json['fecha_hora_inicio'] != null
          ? DateTime.tryParse(json['fecha_hora_inicio'].toString())
          : null,
      nombreCliente: json['nombre_cliente']?.toString() ?? 'Sin nombre',
      nombreTratamiento: json['nombre_tratamiento']?.toString() ?? 'Sin tratamiento',
      estadoPago: json['estado_pago']?.toString() ?? 'pendiente',
      saldoPendiente: (json['saldo_pendiente'] is num)
          ? (json['saldo_pendiente'] as num).toDouble()
          : 0.0,
      numeroSesion: (json['numero_sesion'] is int)
          ? json['numero_sesion']
          : 1,
      ticketId: json['ticket_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sesion_id': sesionId,
      'fecha_hora_inicio': fechaHora?.toIso8601String(),
      'nombre_cliente': nombreCliente,
      'nombre_tratamiento': nombreTratamiento,
      'estado_pago': estadoPago,
      'saldo_pendiente': saldoPendiente,
      'numero_sesion': numeroSesion,
      'ticket_id': ticketId,
    };
  }
}
