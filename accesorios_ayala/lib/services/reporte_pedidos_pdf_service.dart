import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/pedido.dart';

/// Períodos disponibles para el reporte de pedidos en PDF.
enum PeriodoReportePedidos {
  hoy('Hoy'),
  semana('Esta semana'),
  mes('Este mes');

  final String etiqueta;

  const PeriodoReportePedidos(this.etiqueta);
}

/// Resumen calculado para un período del reporte de pedidos.
class DatosReportePedidos {
  final PeriodoReportePedidos periodo;
  final DateTime fechaGeneracionHonduras;
  final DateTime inicioPeriodoHonduras;
  final DateTime finPeriodoHonduras;
  final List<Pedido> pedidos;
  final int cantidadPedidos;
  final double totalRegistrado;
  final int sinFechaCreacion;

  DatosReportePedidos({
    required this.periodo,
    required this.fechaGeneracionHonduras,
    required this.inicioPeriodoHonduras,
    required this.finPeriodoHonduras,
    required List<Pedido> pedidos,
    required this.cantidadPedidos,
    required this.totalRegistrado,
    required this.sinFechaCreacion,
  }) : pedidos = List<Pedido>.unmodifiable(pedidos);
}

/// Servicio independiente para generar el reporte de pedidos en PDF (A4),
/// utilizando el calendario de Honduras (UTC-6) y sin depender de Firebase.
class ReportePedidosPdfService {
  static const String rutaLogoOficial = 'assets/logo/logo_ayala.png';
  static const String rutaFuenteRegular = 'assets/fonts/NotoSans-Regular.ttf';
  static const String rutaFuenteBold = 'assets/fonts/NotoSans-Bold.ttf';
  static const String rutaFuenteItalic = 'assets/fonts/NotoSans-Italic.ttf';
  static const Duration _desfaseHonduras = Duration(hours: 6);

  static const PdfColor _rojoMarca = PdfColor.fromInt(0xFFD9232E);
  static const PdfColor _rosaSuave = PdfColor.fromInt(0xFFFFF5F6);
  static const PdfColor _bordeSuave = PdfColor.fromInt(0xFFF0DDE0);
  static const PdfColor _textoOscuro = PdfColor.fromInt(0xFF202020);
  static const PdfColor _grisTexto = PdfColor.fromInt(0xFF5A5253);

  /// Filtra, ordena y calcula los totales de [pedidos] para [periodo] según el
  /// calendario de Honduras (UTC-6), utilizando `createdAt`.
  static DatosReportePedidos prepararDatos({
    required List<Pedido> pedidos,
    required PeriodoReportePedidos periodo,
    DateTime? fechaReferencia,
  }) {
    final referencia = fechaReferencia ?? DateTime.now();
    final refHonduras = referencia.toUtc().subtract(_desfaseHonduras);
    final hoy = DateTime.utc(
      refHonduras.year,
      refHonduras.month,
      refHonduras.day,
    );

    final DateTime inicioPeriodo;
    final DateTime finPeriodo;
    switch (periodo) {
      case PeriodoReportePedidos.hoy:
        inicioPeriodo = hoy;
        finPeriodo = hoy;
      case PeriodoReportePedidos.semana:
        inicioPeriodo = hoy.subtract(Duration(days: hoy.weekday - 1));
        finPeriodo = inicioPeriodo.add(const Duration(days: 6));
      case PeriodoReportePedidos.mes:
        inicioPeriodo = DateTime.utc(hoy.year, hoy.month, 1);
        finPeriodo = DateTime.utc(hoy.year, hoy.month + 1, 0);
    }

    final filtrados = <Pedido>[];
    var centavosTotales = 0;
    var sinFechaCreacion = 0;

    for (final pedido in pedidos) {
      final createdAt = pedido.createdAt;
      if (createdAt == null) {
        sinFechaCreacion++;
        continue;
      }

      final creadoHn = createdAt.toUtc().subtract(_desfaseHonduras);
      final creadoDia = DateTime.utc(
        creadoHn.year,
        creadoHn.month,
        creadoHn.day,
      );

      if (creadoDia.isBefore(inicioPeriodo) || creadoDia.isAfter(finPeriodo)) {
        continue;
      }

      filtrados.add(pedido);
      centavosTotales += _aCentavos(pedido.totalEstimado);
    }

    filtrados.sort((a, b) {
      final fechaCmp = a.createdAt!.toUtc().compareTo(b.createdAt!.toUtc());
      if (fechaCmp != 0) return fechaCmp;

      final numCmp = a.numeroPedido.trim().compareTo(b.numeroPedido.trim());
      if (numCmp != 0) return numCmp;

      return a.id.compareTo(b.id);
    });

    return DatosReportePedidos(
      periodo: periodo,
      fechaGeneracionHonduras: refHonduras,
      inicioPeriodoHonduras: inicioPeriodo,
      finPeriodoHonduras: finPeriodo,
      pedidos: filtrados,
      cantidadPedidos: filtrados.length,
      totalRegistrado: centavosTotales / 100.0,
      sinFechaCreacion: sinFechaCreacion,
    );
  }

  /// Genera el documento PDF A4 con el reporte de [pedidos] para [periodo].
  static Future<Uint8List> generarReporte({
    required List<Pedido> pedidos,
    required PeriodoReportePedidos periodo,
    DateTime? fechaReferencia,
    AssetBundle? bundle,
  }) async {
    final datos = prepararDatos(
      pedidos: pedidos,
      periodo: periodo,
      fechaReferencia: fechaReferencia,
    );

    final assetBundle = bundle ?? rootBundle;

    final pw.MemoryImage logo;
    try {
      final logoBytes = await assetBundle.load(rutaLogoOficial);
      logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      throw StateError(
        'No se pudo cargar el logo oficial de Accesorios Ayala ($rutaLogoOficial): $e',
      );
    }

    final fontRegular = await _cargarFuente(assetBundle, rutaFuenteRegular);
    final fontBold = await _cargarFuente(assetBundle, rutaFuenteBold);
    final fontItalic = await _cargarFuente(assetBundle, rutaFuenteItalic);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final rangoTexto = datos.inicioPeriodoHonduras == datos.finPeriodoHonduras
        ? _formatearFecha(datos.inicioPeriodoHonduras)
        : '${_formatearFecha(datos.inicioPeriodoHonduras)} al ${_formatearFecha(datos.finPeriodoHonduras)}';
    final generadoTexto =
        '${_formatearFechaHora(datos.fechaGeneracionHonduras)} (UTC-6)';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        footer: (context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Divider(color: _bordeSuave, thickness: 0.8, height: 1),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Accesorios Ayala · Reporte de Pedidos',
                  style: const pw.TextStyle(fontSize: 8.5, color: _grisTexto),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _grisTexto),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          // Encabezado institucional
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: _rosaSuave,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _bordeSuave, width: 1),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 56,
                  height: 56,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: _bordeSuave, width: 0.8),
                  ),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Accesorios Ayala',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: _rojoMarca,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Reporte de Pedidos',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: _textoOscuro,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Período: ${datos.periodo.etiqueta} ($rangoTexto) · Moneda: HNL',
                        style: const pw.TextStyle(
                          fontSize: 9.5,
                          color: _grisTexto,
                        ),
                      ),
                      pw.Text(
                        'Generado: $generadoTexto',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: _grisTexto,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 14),

          // Indicadores resumen
          pw.Row(
            children: [
              pw.Expanded(
                child: _construirTarjetaResumen(
                  etiqueta: 'Cantidad de pedidos',
                  valor:
                      '${datos.cantidadPedidos} ${datos.cantidadPedidos == 1 ? 'pedido' : 'pedidos'}',
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _construirTarjetaResumen(
                  etiqueta: 'Total registrado (HNL)',
                  valor: formatearLempiras(datos.totalRegistrado),
                  destacar: true,
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          if (datos.pedidos.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: _rosaSuave,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _bordeSuave, width: 0.8),
              ),
              child: pw.Center(
                child: pw.Text(
                  'No se registraron pedidos en este período.',
                  style: const pw.TextStyle(fontSize: 10.5, color: _grisTexto),
                ),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: _bordeSuave, width: 0.7),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.6),
                1: pw.FlexColumnWidth(2.6),
                2: pw.FlexColumnWidth(1.9),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  repeat: true,
                  decoration: const pw.BoxDecoration(color: _rojoMarca),
                  children: [
                    _celdaEncabezado('N.° Pedido'),
                    _celdaEncabezado('Cliente'),
                    _celdaEncabezado('Fecha'),
                    _celdaEncabezado('Estado'),
                    _celdaEncabezado('Importe (L.)', alinearDerecha: true),
                  ],
                ),
                for (var i = 0; i < datos.pedidos.length; i++)
                  _construirFilaPedido(
                    datos.pedidos[i],
                    sombreada: i.isOdd,
                  ),
              ],
            ),

          pw.SizedBox(height: 14),

          // Total general al final
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: pw.BoxDecoration(
                color: _rosaSuave,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _bordeSuave, width: 1),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total general:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _textoOscuro,
                    ),
                  ),
                  pw.Text(
                    formatearLempiras(datos.totalRegistrado),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _rojoMarca,
                    ),
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 14),

          pw.Text(
            'Los importes representan el valor de los pedidos registrados, no necesariamente dinero recibido.',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: _grisTexto,
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _construirTarjetaResumen({
    required String etiqueta,
    required String valor,
    bool destacar = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _bordeSuave, width: 0.9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            etiqueta,
            style: const pw.TextStyle(fontSize: 9, color: _grisTexto),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            valor,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: destacar ? _rojoMarca : _textoOscuro,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _celdaEncabezado(
    String texto, {
    bool alinearDerecha = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        texto,
        textAlign: alinearDerecha ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.TableRow _construirFilaPedido(
    Pedido pedido, {
    required bool sombreada,
  }) {
    final numero = pedido.numeroPedido.trim().isNotEmpty
        ? pedido.numeroPedido.trim()
        : 'Sin número';
    final creadoHn = pedido.createdAt!.toUtc().subtract(_desfaseHonduras);

    return pw.TableRow(
      decoration: sombreada ? const pw.BoxDecoration(color: _rosaSuave) : null,
      children: [
        _celdaDato(numero, negrita: true),
        _celdaDato(pedido.clienteNombre),
        _celdaDato(_formatearFechaHora(creadoHn)),
        _celdaDato(pedido.estadoEnvio.etiqueta),
        _celdaDato(
          formatearLempiras(pedido.totalEstimado),
          alinearDerecha: true,
          negrita: true,
        ),
      ],
    );
  }

  static pw.Widget _celdaDato(
    String texto, {
    bool alinearDerecha = false,
    bool negrita = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        texto,
        textAlign: alinearDerecha ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _textoOscuro,
        ),
      ),
    );
  }

  /// Convierte un monto en lempiras a centavos enteros redondeados.
  static int _aCentavos(double monto) => (monto * 100).round();

  /// Formatea [monto] en lempiras utilizando exactamente el mismo redondeo a
  /// centavos enteros que el total general.
  static String formatearLempiras(double monto) {
    final centavos = _aCentavos(monto);
    return 'L. ${(centavos / 100.0).toStringAsFixed(2)}';
  }

  static Future<pw.Font> _cargarFuente(
    AssetBundle assetBundle,
    String ruta,
  ) async {
    try {
      final bytes = await assetBundle.load(ruta);
      return pw.Font.ttf(bytes);
    } catch (e) {
      throw StateError(
        'No se pudo cargar la fuente Unicode de reportes ($ruta): $e',
      );
    }
  }

  static String _formatearFecha(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  static String _formatearFechaHora(DateTime fecha) {
    final h = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '${_formatearFecha(fecha)} $h:$min';
  }
}
