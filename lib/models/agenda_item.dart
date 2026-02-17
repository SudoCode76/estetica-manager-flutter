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
    // Extraer cliente de múltiples formas (cliente Map, lista, o campos planos)
    String extractClienteName(Map<String, dynamic> j) {
      try {
        final clienteObj = j['cliente'] ?? j['cliente_id'] ?? j['clienteData'];
        String nombre = '';
        String apellido = '';

        if (clienteObj is List && clienteObj.isNotEmpty) {
          final c0 = clienteObj.first;
          if (c0 is Map) {
            nombre =
                (c0['nombrecliente'] ??
                        c0['nombreCliente'] ??
                        c0['nombre'] ??
                        '')
                    .toString();
            apellido =
                (c0['apellidocliente'] ??
                        c0['apellidoCliente'] ??
                        c0['apellido'] ??
                        '')
                    .toString();
          }
        } else if (clienteObj is Map) {
          nombre =
              (clienteObj['nombrecliente'] ??
                      clienteObj['nombreCliente'] ??
                      clienteObj['nombre'] ??
                      '')
                  .toString();
          apellido =
              (clienteObj['apellidocliente'] ??
                      clienteObj['apellidoCliente'] ??
                      clienteObj['apellido'] ??
                      '')
                  .toString();
        } else {
          nombre =
              (j['nombrecliente'] ??
                      j['nombre_cliente'] ??
                      j['nombreCliente'] ??
                      j['nombre'] ??
                      '')
                  .toString();
          apellido =
              (j['apellidocliente'] ??
                      j['apellidoCliente'] ??
                      j['apellido'] ??
                      '')
                  .toString();
        }

        final full = ('$nombre $apellido').trim();
        return full.isNotEmpty ? full : 'Sin nombre';
      } catch (_) {
        return 'Sin nombre';
      }
    }

    // Extraer tratamiento de múltiples ubicaciones (tratamiento Map, sesiones -> tratamiento, o campos planos)
    String extractTratamientoName(Map<String, dynamic> j) {
      try {
        // 1) revisar clave 'tratamiento'
        var tratObj = j['tratamiento'];
        // 2) algunas vistas traen sesiones con tratamiento incrustado
        if (tratObj == null) {
          // si existe 'sesiones' y es lista, intentar obtener el tratamiento de la primera sesion
          final sesiones = j['sesiones'] ?? j['sesion'] ?? j['session'];
          if (sesiones is List && sesiones.isNotEmpty) {
            final s0 = sesiones.first;
            if (s0 is Map) {
              tratObj =
                  s0['tratamiento'] ??
                  s0['tratamiento_id'] ??
                  s0['tratamiento_id'];
            }
          } else if (sesiones is Map) {
            tratObj = sesiones['tratamiento'] ?? sesiones['tratamiento_id'];
          }
        }

        String nombreTrat = '';
        if (tratObj is List && tratObj.isNotEmpty) {
          final t0 = tratObj.first;
          if (t0 is Map) {
            nombreTrat =
                (t0['nombretratamiento'] ??
                        t0['nombreTratamiento'] ??
                        t0['nombre'] ??
                        '')
                    .toString();
          }
        } else if (tratObj is Map) {
          nombreTrat =
              (tratObj['nombretratamiento'] ??
                      tratObj['nombreTratamiento'] ??
                      tratObj['nombre'] ??
                      '')
                  .toString();
        }

        if (nombreTrat.isEmpty) {
          nombreTrat =
              (j['nombretratamiento'] ??
                      j['nombre_tratamiento'] ??
                      j['nombreTratamiento'] ??
                      j['nombre_trat'] ??
                      '')
                  .toString();
        }

        return nombreTrat.isNotEmpty ? nombreTrat : 'Sin tratamiento';
      } catch (_) {
        return 'Sin tratamiento';
      }
    }

    return AgendaItem(
      sesionId: json['sesion_id']?.toString() ?? json['id']?.toString() ?? '',
      fechaHora: json['fecha_hora_inicio'] != null
          ? DateTime.tryParse(json['fecha_hora_inicio'].toString())
          : null,
      nombreCliente: extractClienteName(json),
      nombreTratamiento: extractTratamientoName(json),
      estadoPago: json['estado_pago']?.toString() ?? 'pendiente',
      saldoPendiente: (json['saldo_pendiente'] is num)
          ? (json['saldo_pendiente'] as num).toDouble()
          : (json['saldo'] is num ? (json['saldo'] as num).toDouble() : 0.0),
      numeroSesion: (json['numero_sesion'] is int)
          ? json['numero_sesion']
          : (json['numeroSesion'] is int ? json['numeroSesion'] : 1),
      ticketId: json['ticket_id']?.toString() ?? json['ticketId']?.toString(),
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
