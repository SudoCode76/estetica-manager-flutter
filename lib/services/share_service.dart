import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, MethodChannel;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional web helper (implemented in web_file_utils.dart)
import 'web_file_utils_io.dart'
    if (dart.library.html) 'web_file_utils.dart'
    as web_utils;

class ShareService {
  static const MethodChannel _channel = MethodChannel('app_estetica/share');

  // Genera un PDF básico a partir de los datos del ticket con diseño mejorado
  static Future<Uint8List> buildTicketPdf(Map<String, dynamic> ticket) async {
    final pdf = pw.Document();

    // Soportar dos estructuras: la antigua con 'tratamientos' o la nueva con 'sesiones'.
    final tratamientosRaw = ticket['tratamientos'] as List<dynamic>?;
    final sesionesRaw = ticket['sesiones'] as List<dynamic>?;
    final cliente = ticket['cliente'] ?? {};
    final id = ticket['documentId'] ?? ticket['id'] ?? '';

    // Construir una lista de tratamientos a partir de sesiones cuando no exista el arreglo 'tratamientos'
    List<Map<String, dynamic>> tratamientos = [];
    if (tratamientosRaw != null && tratamientosRaw.isNotEmpty) {
      tratamientos = tratamientosRaw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (sesionesRaw != null && sesionesRaw.isNotEmpty) {
      // Agrupar sesiones por tratamiento y almacenar también las fechas/hora de cada sesión
      final Map<dynamic, Map<String, dynamic>> map = {};
      for (final s in sesionesRaw) {
        try {
          final trat = s['tratamiento'] ?? s['tratamiento_id'] ?? {};
          final tratId = trat is Map
              ? (trat['id'] ?? trat['ID'])
              : (s['tratamiento_id'] ?? trat);
          final nombre = (trat is Map)
              ? (trat['nombretratamiento'] ??
                    trat['nombreTratamiento'] ??
                    trat['name'] ??
                    'Tratamiento')
              : 'Tratamiento';
          // precio por sesión puede venir en la sesion como 'precio_sesion' o en tratamiento como 'precio'
          double precioSesion = 0.0;
          if (s is Map &&
              s.containsKey('precio_sesion') &&
              s['precio_sesion'] != null) {
            precioSesion =
                double.tryParse(s['precio_sesion'].toString()) ?? 0.0;
          } else if (trat is Map && trat['precio'] != null) {
            precioSesion = double.tryParse(trat['precio'].toString()) ?? 0.0;
          }

          // Formatear la fecha/hora de la sesión si existe
          String? fechaStr;
          if (s is Map && s['fecha_hora_inicio'] != null) {
            try {
              final dt = DateTime.parse(s['fecha_hora_inicio'].toString());
              fechaStr = DateFormat('dd/MM/yyyy • HH:mm', 'es').format(dt);
            } catch (_) {
              fechaStr = s['fecha_hora_inicio'].toString();
            }
          }

          if (map.containsKey(tratId)) {
            map[tratId]!['cantidad'] = (map[tratId]!['cantidad'] as int) + 1;
            map[tratId]!['subtotal'] =
                (map[tratId]!['subtotal'] as double) + precioSesion;
            // añadir fecha a la lista
            final List<String> fechas = List<String>.from(
              map[tratId]!['fechas'] ?? <String>[],
            );
            if (fechaStr != null) fechas.add(fechaStr);
            map[tratId]!['fechas'] = fechas;
          } else {
            map[tratId] = {
              'id': tratId,
              'nombreTratamiento': nombre,
              'precio': precioSesion,
              'cantidad': 1,
              'subtotal': precioSesion,
              'fechas': fechaStr != null ? <String>[fechaStr] : <String>[],
            };
          }
        } catch (_) {}
      }
      tratamientos = map.values
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } else {
      tratamientos = [];
    }

    final total = tratamientos.fold<double>(0, (p, e) {
      // Si existe subtotal, usarlo; si no, usar precio * cantidad
      final subtotal = (e['subtotal'] is num)
          ? (e['subtotal'] as num).toDouble()
          : null;
      if (subtotal != null) return p + subtotal;
      final precio = (e['precio'] is num)
          ? (e['precio'] as num).toDouble()
          : (double.tryParse(e['precio']?.toString() ?? '0') ?? 0.0);
      final cantidad = (e['cantidad'] is num)
          ? (e['cantidad'] as num).toInt()
          : 1;
      return p + precio * cantidad;
    });

    // Intentar cargar logo desde assets (assets/logo.png)
    Uint8List? logoBytes;
    try {
      final bytes = await rootBundle.load('assets/logo.png');
      logoBytes = bytes.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    final fecha = ticket['fecha'] != null
        ? DateTime.tryParse(ticket['fecha'])
        : DateTime.now();
    final fechaStr = fecha != null
        ? DateFormat('dd MMM yyyy').format(fecha)
        : '';
    final horaStr = fecha != null ? DateFormat('HH:mm').format(fecha) : '';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              width: 380, // tamaño tipo ticket
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(12),
                // boxShadow removed because pw.Offset isn't available here
                // boxShadow: [pw.BoxShadow(color: PdfColors.grey300, blurRadius: 4, offset: const pw.Offset(0, 2))],
              ),
              padding: pw.EdgeInsets.symmetric(vertical: 20, horizontal: 18),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Header centrado con emoji/logo
                  if (logoBytes != null)
                    pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(logoBytes),
                        width: 64,
                        height: 64,
                      ),
                    )
                  else
                    pw.Center(
                      child: pw.Text('🎉', style: pw.TextStyle(fontSize: 28)),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      'Gracias!',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Text(
                      'Su ticket ha sido emitido con éxito',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 12),
                  // ID y amount
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TICKET ID',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            id.toString(),
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Cantidad',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            'Bs ${total.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),
                  // Fecha y hora y cliente
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'FECHA Y HORA',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            '$fechaStr • $horaStr',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.Container(width: 120),
                    ],
                  ),

                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (cliente['nombreCliente'] ??
                                  cliente['nombrecliente'] ??
                                  cliente['name'] ??
                                  '')
                              .toString(),
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if ((cliente['telefono'] ?? cliente['phone']) != null)
                          pw.Text(
                            'Tel: ${cliente['telefono'] ?? cliente['phone']}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 12),
                  // Lista de tratamientos con sus fechas de sesiones
                  pw.Column(
                    children: [
                      ...tratamientos.map((t) {
                        final name =
                            t['nombreTratamiento'] ?? t['nombre'] ?? '-';
                        final cantidad = (t['cantidad'] ?? 1).toString();
                        final subtotal = (t['subtotal'] is num)
                            ? (t['subtotal'] as num).toDouble()
                            : ((t['precio'] is num
                                      ? (t['precio'] as num).toDouble()
                                      : double.tryParse(
                                              t['precio']?.toString() ?? '0',
                                            ) ??
                                            0.0) *
                                  (t['cantidad'] ?? 1));
                        final fechas = List<String>.from(
                          t['fechas'] ?? <String>[],
                        );

                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Expanded(
                                  child: pw.Text(
                                    '$name x$cantidad',
                                    style: pw.TextStyle(
                                      fontSize: 11,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                                pw.Text(
                                  'Bs ${subtotal.toStringAsFixed(2)}',
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (fechas.isNotEmpty)
                              pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  top: 4,
                                  bottom: 8,
                                  left: 2,
                                ),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: fechas
                                      .map(
                                        (f) => pw.Text(
                                          '• $f',
                                          style: pw.TextStyle(
                                            fontSize: 10,
                                            color: PdfColors.grey600,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              )
                            else
                              pw.SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                    ],
                  ),

                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Bs ${total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 18),
                  // Separador punteado
                  pw.Container(
                    height: 1,
                    child: pw.Row(
                      children: List.generate(
                        60,
                        (i) => pw.Expanded(
                          child: pw.Container(
                            color: i % 2 == 0
                                ? PdfColors.white
                                : PdfColors.grey300,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 12),
                  // Mostrar únicamente el ID en texto (código de barras eliminado por requerimiento)
                  pw.Center(
                    child: pw.Text(
                      id.toString(),
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Captura como PNG el widget identificado por key (RepaintBoundary)
  static Future<Uint8List> captureWidgetAsPng(
    GlobalKey key, {
    double pixelRatio = 2.0,
  }) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Widget no renderizado');
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('No se pudo convertir la imagen');
    return byteData.buffer.asUint8List();
  }

  // Escribe bytes en un archivo temporal y devuelve el File
  static Future<File> writeTempFile(Uint8List bytes, String filename) async {
    // On web, use the download helper and return a dummy File is not possible.
    if (kIsWeb) {
      // Trigger browser download and then throw to indicate no File available
      await web_utils.downloadFileWeb(bytes, filename);
      throw UnsupportedError(
        'File objects are not available on web; download triggered',
      );
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      // Algunos entornos (tests, web runner o plataformas no soportadas) lanzan MissingPluginException
      // En esos casos, caemos al directorio temporal del sistema usando dart:io
      try {
        final tmp = Directory.systemTemp;
        final file = File('${tmp.path}/$filename');
        await file.writeAsBytes(bytes, flush: true);
        return file;
      } catch (e2) {
        // Si aún falla, re-lanzar la excepción original para que el caller lo maneje
        rethrow;
      }
    }
  }

  // Compartir archivo usando la API moderna de share_plus (SharePlus.instance.share)
  static Future<void> shareFile(File file, {String? text}) async {
    final xfile = XFile(file.path);
    try {
      final params = ShareParams(files: [xfile], text: text ?? '');
      await SharePlus.instance.share(params);
    } catch (e) {
      // Fallback: intentar con la API estática por compatibilidad
      try {
        // ignore: deprecated_member_use
        await Share.shareXFiles([xfile], text: text ?? '');
      } catch (_) {
        try {
          // último recurso: compartir solo texto
          // ignore: deprecated_member_use
          await Share.share(text ?? '');
        } catch (_) {}
      }
    }
  }

  // Compartir a partir de bytes (sin necesidad de crear File)
  static Future<void> shareBytes(
    Uint8List bytes,
    String filename, {
    String? text,
  }) async {
    if (kIsWeb) {
      // En web, simplemente desencadenar la descarga
      await web_utils.downloadFileWeb(bytes, filename);
      return;
    }

    try {
      // Crear XFile desde memoria (cross_file) y usar share_plus
      final xfile = XFile.fromData(
        bytes,
        name: filename,
        mimeType: 'application/pdf',
      );
      final params = ShareParams(files: [xfile], text: text ?? '');
      await SharePlus.instance.share(params);
    } catch (e) {
      try {
        // Fallback: usar la API estática
        final xfile = XFile.fromData(
          bytes,
          name: filename,
          mimeType: 'application/pdf',
        );
        // ignore: deprecated_member_use
        await Share.shareXFiles([xfile], text: text ?? '');
      } catch (_) {
        await Share.share(text ?? '');
      }
    }
  }

  static Future<bool> shareFileToWhatsAppNative(
    File file, {
    String caption = '',
    String? package,
    String? phone,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareFileToWhatsApp', {
        'path': file.path,
        'caption': caption,
        'package': package,
        'phone': phone,
      });
      return result == true;
    } catch (e) {
      // Fallback: usar share_plus para abrir share sheet
      try {
        await shareFile(file, text: caption);
      } catch (_) {}
      return false;
    }
  }

  // Shortcut: generar PDF, guardar y compartir
  static Future<void> generatePdfAndShare(Map<String, dynamic> ticket) async {
    final bytes = await buildTicketPdf(ticket);
    final nameBase =
        (ticket['documentId'] ??
                ticket['id'] ??
                DateTime.now().millisecondsSinceEpoch.toString())
            .toString();
    final filename = '${sanitizeFileName(nameBase)}_ticket.pdf';
    final file = await writeTempFile(bytes, filename);
    await shareFile(file, text: 'Ticket: $nameBase');
  }

  // Generar PDF de un reporte (daily report)
  static Future<Uint8List> buildReportPdf(
    Map<String, dynamic> report, {
    String? title,
    String? sucursalName,
  }) async {
    final pdf = pw.Document();

    // Header values
    final totalPayments = report['totalPayments'] ?? 0.0;
    final pendingDebt = report['pendingDebt'] ?? 0.0;
    final totalTickets = report['totalTickets'] ?? 0;
    final byDay = List<dynamic>.from(report['byDay'] ?? []);

    // Try load logo
    Uint8List? logoBytes;
    try {
      final bytes = await rootBundle.load('assets/logo.png');
      logoBytes = bytes.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logoBytes != null)
                      pw.Image(pw.MemoryImage(logoBytes), width: 48, height: 48)
                    else
                      pw.Container(),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          title ?? 'Reporte',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        if (sucursalName != null)
                          pw.Text(
                            sucursalName,
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Generado: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Ingresos',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Bs ${double.tryParse(totalPayments.toString())?.toStringAsFixed(2) ?? totalPayments.toString()}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Deuda pendiente',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Bs ${double.tryParse(pendingDebt.toString())?.toStringAsFixed(2) ?? pendingDebt.toString()}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Tickets',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      '${totalTickets}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 16),
                pw.Text(
                  'Detalle por día',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.TableHelper.fromTextArray(
                  headers: ['Fecha', 'Ingresos', 'Deuda', 'Tickets'],
                  data: byDay
                      .map(
                        (d) => [
                          d['date'] ?? '',
                          (d['payments'] ?? 0).toString(),
                          (d['pendingDebt'] ?? 0).toString(),
                          (d['tickets'] ?? 0).toString(),
                        ],
                      )
                      .toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
                ),

                pw.Spacer(),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'Gracias por usar la aplicación',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Generar CSV simple para el reporte
  static Uint8List buildReportCsv(Map<String, dynamic> report) {
    final buffer = StringBuffer();
    buffer.writeln('Fecha,Ingresos,Deuda,Tickets');
    final byDay = List<dynamic>.from(report['byDay'] ?? []);
    for (final d in byDay) {
      final date = d['date'] ?? '';
      final payments = d['payments']?.toString() ?? '0';
      final debt = d['pendingDebt']?.toString() ?? '0';
      final tickets = d['tickets']?.toString() ?? '0';
      buffer.writeln('$date,$payments,$debt,$tickets');
    }
    return Uint8List.fromList(buffer.toString().codeUnits);
  }

  // Escribir CSV/PDF y compartir
  static Future<void> generateReportPdfAndShare(
    Map<String, dynamic> report, {
    String? title,
    String? sucursalName,
  }) async {
    final bytes = await buildReportPdf(
      report,
      title: title,
      sucursalName: sucursalName,
    );
    final filename = 'reporte_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = await writeTempFile(bytes, filename);
    await shareFile(file, text: title ?? 'Reporte');
  }

  static Future<void> generateReportCsvAndShare(
    Map<String, dynamic> report, {
    String? title,
  }) async {
    final bytes = buildReportCsv(report);
    final filename = 'reporte_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = await writeTempFile(bytes, filename);
    await shareFile(file, text: title ?? 'Reporte CSV');
  }

  static String sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r"[^a-zA-Z0-9-_\.]"), '_');
  }
}
