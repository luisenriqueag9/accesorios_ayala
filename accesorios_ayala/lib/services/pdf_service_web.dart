import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  }) async {
    final pdf = pw.Document();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final facturaNo = DateTime.now().millisecondsSinceEpoch.toString();

    double subtotal = 0;
    for (var item in seleccionados) {
      final p = item['producto'] as Producto;
      final c = item['cantidad'] as int;
      subtotal += p.precio * c;
    }

    final impuesto = subtotal * (impuestoPorcentaje / 100);
    final total = subtotal + impuesto;

    // ✅ LOGO CORRECTO (ruta real)
    final logoBytes = await rootBundle.load('assets/logo/logo_ayala.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final Map<String, pw.MemoryImage> imagenesProductos = {};

    for (var item in seleccionados) {
      final p = item['producto'] as Producto;

      if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
        final response = await http.get(Uri.parse(p.imageUrl!));

        if (response.statusCode == 200) {
          imagenesProductos[p.id] = pw.MemoryImage(response.bodyBytes);
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ===== ENCABEZADO =====
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Image(logo, width: 70),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ACCESORIOS AYALA',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('Choloma, Cortés'),
                          pw.Text('Tel: 9912-7141'),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Fecha'),
                      pw.Text(fecha),
                      pw.Text('Factura No: $facturaNo'),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),
              pw.Divider(),

              pw.SizedBox(height: 14),
              pw.Center(
                child: pw.Text(
                  'FACTURA / RECIBO DE COMPRA',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 14),

              // ===== CLIENTE =====
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DATOS DEL CLIENTE',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Nombre: ${cliente.nombre}'),
                    pw.Text('Teléfono: ${cliente.telefono}'),
                    pw.Text('Dirección: ${cliente.direccion}'),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ===== PRODUCTOS =====
              pw.Table(
                border: pw.TableBorder.all(
                  width: 0.5,
                  color: PdfColors.grey600,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(60),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Foto'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Descripción'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Total'),
                      ),
                    ],
                  ),

                  ...seleccionados.map((item) {
                    final p = item['producto'] as Producto;
                    final c = item['cantidad'] as int;

                    // ✅ IMAGEN PROTEGIDA (NO ROMPE EL PDF)
                    final imagenProducto = imagenesProductos.containsKey(p.id)
                        ? pw.Image(
                            imagenesProductos[p.id]!,
                            width: 35,
                            height: 35,
                            fit: pw.BoxFit.cover,
                          )
                        : pw.Container(
                            width: 35,
                            height: 35,
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'SIN FOTO',
                              style: pw.TextStyle(fontSize: 6),
                            ),
                          );

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: imagenProducto,
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${p.nombre} x$c'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Lps ${(p.precio * c).toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 18),

              // ===== TOTALES =====
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 230,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: Lps ${subtotal.toStringAsFixed(2)}'),
                      pw.Text(
                        'ISV (${impuestoPorcentaje.toStringAsFixed(0)}%): Lps ${impuesto.toStringAsFixed(2)}',
                      ),
                      pw.Divider(),
                      pw.Text(
                        'TOTAL: Lps ${total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              pw.SizedBox(height: 25),

              // ===== PIE =====
              pw.Center(child: pw.Text('Atendido por: Marvin Ayala')),
              pw.SizedBox(height: 10),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Facebook: Accesorios Ayala'),
                      pw.Text('Instagram: @accesoriosayala.hn'),
                    ],
                  ),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: 'https://wa.me/50499127141',
                    width: 70,
                    height: 70,
                  ),
                ],
              ),

              pw.SizedBox(height: 15),
              pw.Divider(),

              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Gracias por su compra  Accesorios Ayala © 2026'),
                    pw.Text('Choloma, Cortés | Tel: 9912-7141'),
                    pw.Text(
                      'Este documento es válido sin firma.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
