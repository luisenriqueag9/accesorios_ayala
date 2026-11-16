import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cliente.dart';
import '../models/producto.dart';

class PdfWebService {
  static Future<Uint8List> generarReciboPro({
    required Cliente cliente,
    required List<Map<String, dynamic>> seleccionados,
    required double impuestoPorcentaje,
    double envio = 0.0,
    bool descuentoMayoristaActivo = false,
    double descuentoPorcentaje = 0.0,
    String? facturaNumero,
    DateTime? fechaEmision,
    double? subtotalOverride,
    double? descuentoMontoOverride,
    double? impuestoOverride,
    double? totalOverride,
  }) async {
    final Stopwatch? relojTotal = kDebugMode ? (Stopwatch()..start()) : null;
    final pdf = pw.Document();
    final fecha = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(fechaEmision ?? DateTime.now());
    final facturaNo = (facturaNumero != null && facturaNumero.isNotEmpty)
        ? facturaNumero
        : DateTime.now().millisecondsSinceEpoch.toString();

    double subtotalCalculado = 0;
    for (var item in seleccionados) {
      final p = item['producto'] as Producto;
      final c = item['cantidad'] as int;
      subtotalCalculado += p.precio * c;
    }

    final subtotal = subtotalOverride ?? subtotalCalculado;
    final envioSeguro = envio < 0 ? 0.0 : envio;
    final descuentoPorcentajeSeguro = !descuentoMayoristaActivo
        ? 0.0
        : (descuentoPorcentaje < 0
              ? 0.0
              : (descuentoPorcentaje > 100 ? 100.0 : descuentoPorcentaje));
    final descuentoMonto =
        descuentoMontoOverride ??
        (descuentoMayoristaActivo
            ? subtotal * (descuentoPorcentajeSeguro / 100)
            : 0.0);
    final baseImponible = subtotal - descuentoMonto;
    final impuesto =
        impuestoOverride ?? (baseImponible * (impuestoPorcentaje / 100));
    final total = totalOverride ?? (baseImponible + impuesto + envioSeguro);

    // ✅ LOGO CORRECTO (ruta real)
    final logoBytes = await rootBundle.load('assets/logo/logo_ayala.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    const rojoMarca = PdfColor.fromInt(0xFFD9232E);
    const rosaSuave = PdfColor.fromInt(0xFFFFF5F6);
    const bordeSuave = PdfColor.fromInt(0xFFF0DDE0);
    const grisTexto = PdfColor.fromInt(0xFF5A5253);

    pw.Widget filaCliente(String etiqueta, String valor) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 62,
              child: pw.Text(
                etiqueta,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: grisTexto,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(valor, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );
    }

    pw.Widget filaTotal(
      String etiqueta,
      String valor, {
      bool destacar = false,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                etiqueta,
                style: pw.TextStyle(
                  fontSize: destacar ? 13 : 10,
                  fontWeight: destacar
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: destacar ? PdfColors.black : grisTexto,
                ),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              valor,
              style: pw.TextStyle(
                fontSize: destacar ? 14 : 10,
                fontWeight: pw.FontWeight.bold,
                color: destacar ? rojoMarca : PdfColors.black,
              ),
            ),
          ],
        ),
      );
    }

    final Stopwatch? relojPdf = kDebugMode ? (Stopwatch()..start()) : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 24),
        footer: (context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Divider(color: rojoMarca, thickness: 0.8, height: 1),
            pw.SizedBox(height: 6),
            pw.Text(
              'ACCESORIOS AYALA',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: rojoMarca,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Gracias por tu compra',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: grisTexto,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Wrap(
              alignment: pw.WrapAlignment.center,
              crossAxisAlignment: pw.WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 2,
              children: [
                pw.Text(
                  'Facebook: Accesorios Ayala',
                  style: const pw.TextStyle(fontSize: 8, color: grisTexto),
                ),
                pw.Text(
                  '·',
                  style: const pw.TextStyle(fontSize: 8, color: rojoMarca),
                ),
                pw.Text(
                  'Instagram: @accesoriosayala.hn',
                  style: const pw.TextStyle(fontSize: 8, color: grisTexto),
                ),
                pw.Text(
                  '·',
                  style: const pw.TextStyle(fontSize: 8, color: rojoMarca),
                ),
                pw.UrlLink(
                  destination: 'https://wa.me/50499127141',
                  child: pw.Text(
                    'WhatsApp: +504 9912-7141',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: rojoMarca,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.SizedBox(width: 56),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'Atendido por: Marvin Ayala  ·  Choloma, Cortés | Tel: 9912-7141',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: grisTexto,
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'Accesorios Ayala © 2026 · Este documento es válido sin firma.',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 7.5,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 56,
                  child: pw.Text(
                    'Pág. ${context.pageNumber}/${context.pagesCount}',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 8, color: grisTexto),
                  ),
                ),
              ],
            ),
          ],
        ),
        build: (_) => [
          // ===== ENCABEZADO =====
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(logo, width: 72),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ACCESORIOS AYALA',
                            style: pw.TextStyle(
                              fontSize: 19,
                              fontWeight: pw.FontWeight.bold,
                              color: rojoMarca,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Choloma, Cortés',
                            style: const pw.TextStyle(
                              fontSize: 9.5,
                              color: grisTexto,
                            ),
                          ),
                          pw.Text(
                            'Tel: 9912-7141',
                            style: const pw.TextStyle(
                              fontSize: 9.5,
                              color: grisTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  color: rosaSuave,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: bordeSuave, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'FACTURA / RECIBO DE COMPRA',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: rojoMarca,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Factura No: $facturaNo',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Fecha: $fecha',
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: grisTexto,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 10),
          pw.Divider(color: rojoMarca, thickness: 1.4, height: 1),
          pw.SizedBox(height: 12),

          // ===== CLIENTE =====
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: pw.BoxDecoration(
              color: rosaSuave,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: bordeSuave, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DATOS DEL CLIENTE',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: rojoMarca,
                  ),
                ),
                pw.SizedBox(height: 5),
                filaCliente('Nombre:', cliente.nombre),
                filaCliente('Teléfono:', cliente.telefono),
                filaCliente('Dirección:', cliente.direccion),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // ===== PRODUCTOS =====
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: bordeSuave),
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FixedColumnWidth(58),
              2: const pw.FixedColumnWidth(92),
              3: const pw.FixedColumnWidth(92),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: rojoMarca),
                children: [
                  for (final col in const [
                    ('Producto', pw.TextAlign.left),
                    ('Cantidad', pw.TextAlign.center),
                    ('Precio unitario', pw.TextAlign.right),
                    ('Total', pw.TextAlign.right),
                  ])
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: pw.Text(
                        col.$1,
                        textAlign: col.$2,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                ],
              ),

              ...seleccionados.map((item) {
                final p = item['producto'] as Producto;
                final c = item['cantidad'] as int;

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: pw.Text(
                        p.nombre,
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: pw.Text(
                        '$c',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: pw.Text(
                        'Lps ${p.precio.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9.5),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      child: pw.Text(
                        'Lps ${(p.precio * c).toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 14),

          // ===== TOTALES =====
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 270,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: bordeSuave, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  filaTotal('Subtotal:', 'Lps ${subtotal.toStringAsFixed(2)}'),
                  if (descuentoMayoristaActivo)
                    filaTotal(
                      'Descuento mayorista (${descuentoPorcentajeSeguro.toStringAsFixed(descuentoPorcentajeSeguro % 1 == 0 ? 0 : 2)}%):',
                      '- Lps ${descuentoMonto.toStringAsFixed(2)}',
                    ),
                  filaTotal(
                    'ISV (${impuestoPorcentaje.toStringAsFixed(0)}%):',
                    'Lps ${impuesto.toStringAsFixed(2)}',
                  ),
                  filaTotal(
                    'Costo de envío:',
                    'Lps ${envioSeguro.toStringAsFixed(2)}',
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: rosaSuave,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: bordeSuave, width: 0.6),
                    ),
                    child: filaTotal(
                      'TOTAL:',
                      'Lps ${total.toStringAsFixed(2)}',
                      destacar: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    if (kDebugMode && relojPdf != null) {
      relojPdf.stop();
      debugPrint(
        '⏱️ [PDF] Construcción y serialización: ${relojPdf.elapsedMilliseconds} ms',
      );
    }
    if (kDebugMode && relojTotal != null) {
      relojTotal.stop();
      debugPrint(
        '⏱️ [PDF] Tiempo total generarReciboPro (${seleccionados.length} productos): '
        '${relojTotal.elapsedMilliseconds} ms',
      );
    }

    return bytes;
  }
}
