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

class ShareService {
  static const MethodChannel _channel = MethodChannel('app_estetica/share');

  // Genera un PDF básico a partir de los datos del ticket con diseño mejorado
  static Future<Uint8List> buildTicketPdf(Map<String, dynamic> ticket) async {
    final pdf = pw.Document();

    final tratamientos = ticket['tratamientos'] as List<dynamic>? ?? [];
    final cliente = ticket['cliente'] ?? {};
    final id = ticket['documentId'] ?? ticket['id'] ?? '';

    final total = tratamientos.fold<double>(0, (p, e) => p + (double.tryParse(e['precio']?.toString() ?? '0') ?? 0));

    // Intentar cargar logo desde assets (assets/logo.png)
    Uint8List? logoBytes;
    try {
      final bytes = await rootBundle.load('assets/logo.png');
      logoBytes = bytes.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    final fecha = ticket['fecha'] != null ? DateTime.tryParse(ticket['fecha']) : DateTime.now();
    final fechaStr = fecha != null ? DateFormat('dd MMM yyyy').format(fecha) : '';
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
                    pw.Center(child: pw.Image(pw.MemoryImage(logoBytes), width: 64, height: 64))
                  else
                    pw.Center(child: pw.Text('🎉', style: pw.TextStyle(fontSize: 28))),
                  pw.SizedBox(height: 8),
                  pw.Center(child: pw.Text('Gracias!', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 6),
                  pw.Center(child: pw.Text('Su ticket ha sido emitido con éxito', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),

                  pw.SizedBox(height: 12),
                  // ID y amount
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('TICKET ID', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(id.toString(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ]),
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Text('Cantidad', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text('Bs ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ])
                    ],
                  ),

                  pw.SizedBox(height: 12),
                  // Fecha y hora y cliente
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('FECHA Y HORA', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('$fechaStr • $horaStr', style: pw.TextStyle(fontSize: 10)),
                    ]),
                    pw.Container(width: 120),
                  ]),

                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(cliente['nombreCliente'] ?? '', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      if (cliente['telefono'] != null) pw.Text('Tel: ${cliente['telefono']}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ]),
                  ),

                  pw.SizedBox(height: 12),
                  // Lista de tratamientos
                  pw.Column(children: [
                    ...tratamientos.map((t) {
                      final name = t['nombreTratamiento'] ?? '-';
                      final price = t['precio']?.toString() ?? '0';
                      return pw.Padding(
                        padding: pw.EdgeInsets.symmetric(vertical: 6),
                        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Expanded(child: pw.Text(name, style: pw.TextStyle(fontSize: 11))),
                          pw.Text('Bs $price', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ]),
                      );
                    }).toList()
                  ]),

                  pw.Divider(),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Total', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    pw.Text('Bs ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ]),

                  pw.SizedBox(height: 18),
                  // Separador punteado
                  pw.Container(
                    height: 1,
                    child: pw.Row(children: List.generate(60, (i) => pw.Expanded(child: pw.Container(color: i % 2 == 0 ? PdfColors.white : PdfColors.grey300, height: 1)))),
                  ),

                  pw.SizedBox(height: 12),
                  // Barcode simple (simulado)
                  pw.Container(
                    height: 60,
                    child: pw.Center(
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: List.generate(40, (i) {
                          final w = (i % 3) + 1; // widths 1..3
                          return pw.Container(width: w.toDouble(), height: 40, margin: pw.EdgeInsets.symmetric(horizontal: 1), color: (i % 2 == 0) ? PdfColors.black : PdfColors.grey800);
                        }),
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 8),
                  pw.Center(child: pw.Text(id.toString(), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),

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
  static Future<Uint8List> captureWidgetAsPng(GlobalKey key, {double pixelRatio = 2.0}) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Widget no renderizado');
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('No se pudo convertir la imagen');
    return byteData.buffer.asUint8List();
  }

  // Escribe bytes en un archivo temporal y devuelve el File
  static Future<File> writeTempFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
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

  static Future<bool> shareFileToWhatsAppNative(File file, {String caption = '', String? package, String? phone}) async {
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
    final nameBase = (ticket['documentId'] ?? ticket['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();
    final filename = '${sanitizeFileName(nameBase)}_ticket.pdf';
    final file = await writeTempFile(bytes, filename);
    await shareFile(file, text: 'Ticket: $nameBase');
  }

  static String sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r"[^a-zA-Z0-9-_\.]"), '_');
  }
}
