import 'dart:ui';
import 'package:accesorios_ayala/services/pdf_service_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/descargar_pdf_stub.dart'
    if (dart.library.html) '../utils/descargar_pdf_web.dart';
import '../models/venta.dart';
import '../controllers/venta_controller.dart';

import '../models/cliente.dart';
import '../models/producto.dart';

class EstadoFacturaPrevia {
  final String impuestoTexto;
  final String envioTexto;
  final String descuentoTexto;
  final bool descuentoMayoristaActivo;
  final bool ventaGuardada;
  final String? facturaId;
  final DateTime? fechaFactura;
  final Uint8List? pdfBytesEmitido;

  const EstadoFacturaPrevia({
    this.impuestoTexto = '0',
    this.envioTexto = '120.00',
    this.descuentoTexto = '20',
    this.descuentoMayoristaActivo = false,
    this.ventaGuardada = false,
    this.facturaId,
    this.fechaFactura,
    this.pdfBytesEmitido,
  });
}

typedef GeneradorPdfFactura = Future<Uint8List> Function({
  required Cliente cliente,
  required List<Map<String, dynamic>> seleccionados,
  required double impuestoPorcentaje,
  double envio,
  bool descuentoMayoristaActivo,
  double descuentoPorcentaje,
  String? facturaNumero,
  DateTime? fechaEmision,
  double? subtotalOverride,
  double? descuentoMontoOverride,
  double? impuestoOverride,
  double? totalOverride,
});

class VistaPreviaReciboView extends StatefulWidget {
  final Cliente cliente;
  final List<Map<String, dynamic>> seleccionados;
  final bool integrado;
  final VoidCallback? onVolver;
  final EstadoFacturaPrevia? estadoInicial;
  final ValueChanged<EstadoFacturaPrevia>? onEstadoCambiado;
  final bool soloLectura;
  final Venta? ventaHistorica;
  final GeneradorPdfFactura? onGenerarPdf;
  final void Function(Uint8List bytes, String nombreArchivo)? onDescargarPdf;
  final Future<void> Function(Venta venta)? onGuardarVenta;
  final Future<bool> Function(Uri url)? onAbrirWhatsapp;

  const VistaPreviaReciboView({
    super.key,
    required this.cliente,
    required this.seleccionados,
    this.integrado = false,
    this.onVolver,
    this.estadoInicial,
    this.onEstadoCambiado,
    this.soloLectura = false,
    this.ventaHistorica,
    this.onGenerarPdf,
    this.onDescargarPdf,
    this.onGuardarVenta,
    this.onAbrirWhatsapp,
  });

  /// Normaliza teléfonos hondureños al formato requerido por `wa.me` (`504XXXXXXXX`).
  /// Retorna `null` si el número está vacío, incompleto o es ambiguo.
  static String? normalizarTelefonoWhatsApp(String telefono) {
    final limpio = telefono.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (limpio.isEmpty) return null;

    if (limpio.startsWith('+')) {
      final digitos = limpio.substring(1);
      if (RegExp(r'^504\d{8}$').hasMatch(digitos)) {
        return digitos;
      }
      return null;
    }

    if (RegExp(r'^\d{8}$').hasMatch(limpio)) {
      return '504$limpio';
    }

    if (RegExp(r'^504\d{8}$').hasMatch(limpio)) {
      return limpio;
    }

    return null;
  }

  @override
  State<VistaPreviaReciboView> createState() => _VistaPreviaReciboViewState();
}

class _VistaPreviaReciboViewState extends State<VistaPreviaReciboView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  late final TextEditingController impuestoCtrl;
  late final TextEditingController envioCtrl;
  late final TextEditingController descuentoCtrl;

  bool _descuentoMayoristaActivo = false;
  bool _procesandoPdf = false;
  bool _ventaGuardada = false;
  String? _facturaId;
  DateTime? _fechaFactura;
  Uint8List? _pdfBytesEmitido;

  String _formatearPorcentaje(double valor) {
    return valor == valor.roundToDouble()
        ? valor.toInt().toString()
        : valor.toStringAsFixed(2);
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return "$dia/$mes/${fecha.year}";
  }

  @override
  void initState() {
    super.initState();
    final inicial = widget.estadoInicial;
    final historica = widget.ventaHistorica;

    _facturaId = historica?.id ?? inicial?.facturaId;
    _fechaFactura = historica?.fecha ?? inicial?.fechaFactura;

    if (widget.soloLectura &&
        (_facturaId == null ||
            _facturaId!.trim().isEmpty ||
            _fechaFactura == null)) {
      throw ArgumentError(
        "En modo soloLectura se requiere un número de factura y una fecha de emisión válidos.",
      );
    }

    if (historica != null) {
      final base = historica.subtotal - historica.descuentoMonto;
      final impPct = base > 0 ? (historica.impuesto / base) * 100 : 0.0;
      impuestoCtrl = TextEditingController(text: _formatearPorcentaje(impPct));
      envioCtrl = TextEditingController(
        text: historica.envio.toStringAsFixed(2),
      );
      descuentoCtrl = TextEditingController(
        text: _formatearPorcentaje(historica.descuentoPorcentaje),
      );
      _descuentoMayoristaActivo = historica.descuentoMayoristaActivo;
    } else {
      impuestoCtrl = TextEditingController(text: inicial?.impuestoTexto ?? "0");
      envioCtrl = TextEditingController(text: inicial?.envioTexto ?? "120.00");
      descuentoCtrl = TextEditingController(
        text: inicial?.descuentoTexto ?? "20",
      );
      _descuentoMayoristaActivo = inicial?.descuentoMayoristaActivo ?? false;
    }

    _ventaGuardada = widget.soloLectura || (inicial?.ventaGuardada ?? false);
    _pdfBytesEmitido = inicial?.pdfBytesEmitido;
  }

  @override
  void didUpdateWidget(covariant VistaPreviaReciboView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ventaHistorica?.id != oldWidget.ventaHistorica?.id ||
        widget.soloLectura != oldWidget.soloLectura) {
      _pdfBytesEmitido = null;
    }
  }

  void _notificarEstado() {
    widget.onEstadoCambiado?.call(
      EstadoFacturaPrevia(
        impuestoTexto: impuestoCtrl.text,
        envioTexto: envioCtrl.text,
        descuentoTexto: descuentoCtrl.text,
        descuentoMayoristaActivo: _descuentoMayoristaActivo,
        ventaGuardada: _ventaGuardada,
        facturaId: _facturaId,
        fechaFactura: _fechaFactura,
        pdfBytesEmitido: _pdfBytesEmitido,
      ),
    );
  }

  @override
  void dispose() {
    impuestoCtrl.dispose();
    envioCtrl.dispose();
    descuentoCtrl.dispose();
    super.dispose();
  }

  double _parsearDescuentoPorcentaje() {
    if (!_descuentoMayoristaActivo) return 0.0;
    final texto = descuentoCtrl.text.trim().replaceAll(',', '.');
    if (texto.isEmpty) return 0.0;
    final valor = double.tryParse(texto) ?? 0.0;
    if (valor < 0) return 0.0;
    if (valor > 100) return 100.0;
    return valor;
  }

  double _parsearEnvio() {
    final texto = envioCtrl.text.trim().replaceAll(',', '.');
    if (texto.isEmpty) return 0.0;
    final valor = double.tryParse(texto) ?? 0.0;
    return valor < 0 ? 0.0 : valor;
  }

  double calcularSubtotal() {
    double total = 0;
    for (var item in widget.seleccionados) {
      final p = item["producto"] as Producto;
      final c = item["cantidad"] as int;
      total += p.precio * c;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final historica = widget.ventaHistorica;
    final subtotal = historica?.subtotal ?? calcularSubtotal();
    final descuentoPorcentaje =
        historica?.descuentoPorcentaje ?? _parsearDescuentoPorcentaje();
    final descuentoMonto = historica != null
        ? historica.descuentoMonto
        : (_descuentoMayoristaActivo
              ? subtotal * (descuentoPorcentaje / 100)
              : 0.0);
    final baseImponible = subtotal - descuentoMonto;

    final impuestoPorcentaje = historica != null
        ? (baseImponible > 0 ? (historica.impuesto / baseImponible) * 100 : 0.0)
        : (double.tryParse(impuestoCtrl.text.isEmpty ? "0" : impuestoCtrl.text) ??
              0);

    final impuesto =
        historica?.impuesto ?? (baseImponible * (impuestoPorcentaje / 100));
    final costoEnvio = historica?.envio ?? _parsearEnvio();
    final total = historica?.total ?? (baseImponible + impuesto + costoEnvio);

    final contenidoResponsive = LayoutBuilder(
      builder: (context, constraints) {
        final esEscritorio = constraints.maxWidth >= 760;

        final seccionCliente = _construirPanelCristal(
          child: _construirInfoCliente(),
        );

        final seccionProductos = _construirPanelCristal(
          child: _construirListaProductos(),
        );

        final seccionResumen = _construirPanelCristal(
          child: _construirResumenFinanciero(
            subtotal: subtotal,
            descuentoPorcentaje: descuentoPorcentaje,
            descuentoMonto: descuentoMonto,
            impuesto: impuesto,
            costoEnvio: costoEnvio,
            total: total,
          ),
        );

        final seccionBotonPdf = _construirBotonDescargar(
          context: context,
          subtotal: subtotal,
          descuentoPorcentaje: descuentoPorcentaje,
          descuentoMonto: descuentoMonto,
          impuestoPorcentaje: impuestoPorcentaje,
          impuesto: impuesto,
          costoEnvio: costoEnvio,
          total: total,
        );

        if (esEscritorio) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    seccionCliente,
                    const SizedBox(height: 16),
                    seccionProductos,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    seccionResumen,
                    const SizedBox(height: 16),
                    seccionBotonPdf,
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            seccionCliente,
            const SizedBox(height: 16),
            seccionProductos,
            const SizedBox(height: 16),
            seccionResumen,
            const SizedBox(height: 16),
            seccionBotonPdf,
          ],
        );
      },
    );

    if (widget.integrado) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _construirEncabezadoIntegrado(),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: contenidoResponsive,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: _rosaSuave,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _rojoMarca),
        shape: const Border(bottom: BorderSide(color: _bordeSuave, width: 1)),
        title: const Text(
          "Vista previa de factura",
          style: TextStyle(
            color: _rojoMarca,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          _construirFondo(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: contenidoResponsive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEncabezadoIntegrado() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Text(
          "Vista previa de factura",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _negroElegante,
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onVolver?.call(),
          style: OutlinedButton.styleFrom(
            foregroundColor: _grisTexto,
            backgroundColor: Colors.white.withValues(alpha: 0.75),
            side: const BorderSide(color: _bordeSuave),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Volver a Productos'),
        ),
      ],
    );
  }

  Widget _construirFondo() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF4F5), Color(0xFFFFE6E8)],
              stops: [0.0, 0.55, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -70,
          right: -50,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _rojoMarca.withValues(alpha: 0.12),
                  _rojoMarca.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _rojoMarca.withValues(alpha: 0.10),
                  _rojoMarca.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirPanelCristal({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _rojoMarca.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.78),
                  Colors.white.withValues(alpha: 0.56),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _bordeSuave.withValues(alpha: 0.85),
                width: 1.3,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _construirTituloSeccion(
    IconData icono,
    String titulo, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _rosaSuave,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _bordeSuave),
          ),
          child: Icon(icono, color: _rojoMarca, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _negroElegante,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _construirInfoCliente() {
    final mostrarDatosFactura =
        (widget.soloLectura || widget.ventaHistorica != null) &&
        _facturaId != null &&
        _fechaFactura != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirTituloSeccion(
          Icons.person_outline_rounded,
          "Cliente",
          trailing: widget.soloLectura
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _rosaSuave,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _bordeSuave),
                  ),
                  child: const Text(
                    "Solo lectura",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _rojoMarca,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bordeSuave),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mostrarDatosFactura) ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text(
                      "Factura #$_facturaId",
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _rojoMarca,
                      ),
                    ),
                    Text(
                      "Fecha de emisión: ${_formatearFecha(_fechaFactura!)}",
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _grisTexto,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: _bordeSuave),
                const SizedBox(height: 10),
              ],
              Text(
                widget.cliente.nombre,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _negroElegante,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Teléfono: ${widget.cliente.telefono}",
                style: const TextStyle(fontSize: 13.5, color: _grisTexto),
              ),
              const SizedBox(height: 3),
              Text(
                "Dirección: ${widget.cliente.direccion}",
                style: const TextStyle(fontSize: 13.5, color: _grisTexto),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _rosaSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bordeSuave),
      ),
      child: const Icon(Icons.image_outlined, color: _rojoMarca, size: 26),
    );
  }

  Widget _construirListaProductos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirTituloSeccion(
          Icons.shopping_bag_outlined,
          "Productos",
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _rosaSuave.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _bordeSuave),
            ),
            child: Text(
              "${widget.seleccionados.length} ${widget.seleccionados.length == 1 ? 'ítem' : 'ítems'}",
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _rojoMarca,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.seleccionados.map((item) {
          final p = item["producto"] as Producto;
          final c = item["cantidad"] as int;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.80),
                  Colors.white.withValues(alpha: 0.58),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _rojoMarca.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: p.imageUrl != null && p.imageUrl!.trim().isNotEmpty
                      ? Image.network(
                          p.imageUrl!.trim(),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _iconoPlaceholder(),
                        )
                      : _iconoPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _negroElegante,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Cantidad: $c · L. ${p.precio.toStringAsFixed(2)} c/u",
                        style: const TextStyle(fontSize: 13, color: _grisTexto),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Lps ${(p.precio * c).toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: _negroElegante,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _construirCampoNumerico({
    required TextEditingController controller,
    required TextInputType keyboardType,
    List<TextInputFormatter>? inputFormatters,
    double width = 100,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: !widget.soloLectura && !_ventaGuardada && !_procesandoPdf,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: _negroElegante,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.90),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _bordeSuave),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _rojoMarca, width: 1.6),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) {
          setState(() {});
          _notificarEstado();
        },
      ),
    );
  }

  Widget _construirResumenFinanciero({
    required double subtotal,
    required double descuentoPorcentaje,
    required double descuentoMonto,
    required double impuesto,
    required double costoEnvio,
    required double total,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirTituloSeccion(Icons.receipt_long_outlined, "Resumen"),
        const SizedBox(height: 14),
        _fila("Subtotal:", subtotal),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "Descuento mayorista",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _grisTexto,
                ),
              ),
            ),
            Switch(
              value: _descuentoMayoristaActivo,
              activeTrackColor: _rojoMarca.withValues(alpha: 0.35),
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return _rojoMarca;
                }
                return null;
              }),
              onChanged: (widget.soloLectura || _ventaGuardada || _procesandoPdf)
                  ? null
                  : (valor) {
                      setState(() {
                        _descuentoMayoristaActivo = valor;
                      });
                      _notificarEstado();
                    },
            ),
          ],
        ),
        if (_descuentoMayoristaActivo) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Descuento mayorista (%):",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _grisTexto,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _construirCampoNumerico(
                controller: descuentoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*[.,]?\d{0,2}'),
                  ),
                ],
                width: 92,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _fila(
            "Descuento mayorista (${descuentoPorcentaje.toStringAsFixed(descuentoPorcentaje % 1 == 0 ? 0 : 2)}%):",
            descuentoMonto,
            prefijo: "- ",
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "ISV (%):",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _grisTexto,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _construirCampoNumerico(
              controller: impuestoCtrl,
              keyboardType: TextInputType.number,
              width: 92,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _fila("Impuesto:", impuesto),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "Costo de envío (L.):",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _grisTexto,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _construirCampoNumerico(
              controller: envioCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
              ],
              width: 105,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _fila("Costo de envío:", costoEnvio),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(color: _bordeSuave, height: 1),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _rosaSuave.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _bordeSuave),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TOTAL:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _negroElegante,
                ),
              ),
              Text(
                "Lps ${total.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _rojoMarca,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Uint8List> _obtenerOPrepararPdfBytes({
    required double descuentoPorcentaje,
    required double impuestoPorcentaje,
    required double costoEnvio,
  }) async {
    if (_pdfBytesEmitido != null) {
      return _pdfBytesEmitido!;
    }

    final historica = widget.ventaHistorica;
    final generadorPdf = widget.onGenerarPdf ?? PdfWebService.generarReciboPro;
    return generadorPdf(
      cliente: widget.cliente,
      seleccionados: widget.seleccionados,
      impuestoPorcentaje: impuestoPorcentaje,
      envio: costoEnvio,
      descuentoMayoristaActivo: _descuentoMayoristaActivo,
      descuentoPorcentaje: descuentoPorcentaje,
      facturaNumero: _facturaId,
      fechaEmision: widget.soloLectura
          ? _fechaFactura?.toLocal()
          : _fechaFactura,
      subtotalOverride: historica?.subtotal,
      descuentoMontoOverride: historica?.descuentoMonto,
      impuestoOverride: historica?.impuesto,
      totalOverride: historica?.total,
    );
  }

  Future<void> _compartirPorWhatsapp({
    required BuildContext context,
    required double descuentoPorcentaje,
    required double impuestoPorcentaje,
    required double costoEnvio,
    required double total,
  }) async {
    if (_procesandoPdf) return;

    final telefonoWa = VistaPreviaReciboView.normalizarTelefonoWhatsApp(
      widget.cliente.telefono,
    );
    if (telefonoWa == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El cliente no tiene un número de teléfono válido para WhatsApp (+504).',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _procesandoPdf = true;
    });

    try {
      final bytes = await _obtenerOPrepararPdfBytes(
        descuentoPorcentaje: descuentoPorcentaje,
        impuestoPorcentaje: impuestoPorcentaje,
        costoEnvio: costoEnvio,
      );
      _pdfBytesEmitido = bytes;

      final nombreArchivo = 'Factura_${_facturaId!}.pdf';
      final descargar = widget.onDescargarPdf ?? descargarPdfWeb;
      descargar(bytes, nombreArchivo);

      final mensaje =
          'Hola, le compartimos la información de su factura $_facturaId '
          'de Accesorios Ayala, por un total de L. ${total.toStringAsFixed(2)}. '
          'Enviaremos el documento PDF a continuación.';

      final url = Uri.https('wa.me', '/$telefonoWa', {'text': mensaje});
      final abrir =
          widget.onAbrirWhatsapp ??
          (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

      final abierto = await abrir(url);
      if (!abierto) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo abrir WhatsApp. Verifica que esté disponible en tu navegador o dispositivo.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Se descargó $nombreArchivo y se abrió WhatsApp. Adjunta el PDF descargado y confirma el envío manualmente.',
            ),
          ),
        );
      }
    } catch (e, s) {
      debugPrint("❌ ERROR al compartir por WhatsApp");
      debugPrint(e.toString());
      debugPrint(s.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error al preparar la factura para WhatsApp"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _procesandoPdf = false;
        });
      }
    }
  }

  Widget _construirBotonDescargar({
    required BuildContext context,
    required double subtotal,
    required double descuentoPorcentaje,
    required double descuentoMonto,
    required double impuestoPorcentaje,
    required double impuesto,
    required double costoEnvio,
    required double total,
  }) {
    return _construirPanelCristal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _procesandoPdf
                ? null
                : () async {
                    if (_procesandoPdf) return;
                    setState(() {
                      _procesandoPdf = true;
                    });

                    try {
                      debugPrint("👉 Iniciando generación de PDF");

                      if (!widget.soloLectura) {
                        _facturaId ??= DateTime.now().millisecondsSinceEpoch
                            .toString();
                        _fechaFactura ??= DateTime.now();
                        _notificarEstado();
                      }

                      final bytes = await _obtenerOPrepararPdfBytes(
                        descuentoPorcentaje: descuentoPorcentaje,
                        impuestoPorcentaje: impuestoPorcentaje,
                        costoEnvio: costoEnvio,
                      );

                      if (!widget.soloLectura && !_ventaGuardada) {
                        final venta = Venta(
                          id: _facturaId!,
                          clienteId: widget.cliente.id,
                          clienteNombre: widget.cliente.nombre,
                          fecha: _fechaFactura!,
                          subtotal: subtotal,
                          impuesto: impuesto,
                          total: total,
                          envio: costoEnvio,
                          descuentoMayoristaActivo: _descuentoMayoristaActivo,
                          descuentoPorcentaje: descuentoPorcentaje,
                          descuentoMonto: descuentoMonto,
                        );

                        final guardarVenta =
                            widget.onGuardarVenta ??
                            VentaController.guardarVenta;
                        await guardarVenta(venta);

                        if (mounted) {
                          setState(() {
                            _ventaGuardada = true;
                            _pdfBytesEmitido = bytes;
                          });
                        } else {
                          _ventaGuardada = true;
                          _pdfBytesEmitido = bytes;
                        }
                        _notificarEstado();
                      } else if (widget.soloLectura) {
                        _pdfBytesEmitido = bytes;
                      }

                      debugPrint(
                        "✅ PDF generado correctamente (${bytes.length} bytes)",
                      );

                      final nombreArchivo = widget.soloLectura
                          ? 'Factura_${_facturaId!}.pdf'
                          : 'Recibo_AccesoriosAyala_${_facturaId!}.pdf';
                      final descargar = widget.onDescargarPdf ?? descargarPdfWeb;
                      descargar(bytes, nombreArchivo);
                    } catch (e, s) {
                      debugPrint("❌ ERROR al descargar PDF");
                      debugPrint(e.toString());
                      debugPrint(s.toString());

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error al descargar el PDF"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _procesandoPdf = false;
                        });
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _rojoMarca.withValues(alpha: 0.35),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.90),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: _procesandoPdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined, size: 20),
            label: Text(
              _procesandoPdf
                  ? "Procesando..."
                  : ((_ventaGuardada && !widget.soloLectura)
                        ? "Volver a descargar PDF"
                        : "Descargar PDF"),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          if (widget.soloLectura) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _procesandoPdf
                  ? null
                  : () => _compartirPorWhatsapp(
                      context: context,
                      descuentoPorcentaje: descuentoPorcentaje,
                      impuestoPorcentaje: impuestoPorcentaje,
                      costoEnvio: costoEnvio,
                      total: total,
                    ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF15803D),
                side: const BorderSide(color: Color(0xFF86EFAC)),
                backgroundColor: const Color(0xFFF0FDF4),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
              label: const Text(
                "Compartir por WhatsApp",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ),
          ],
          if (widget.soloLectura && _fechaFactura != null) ...[
            const SizedBox(height: 10),
            Text(
              "Factura histórica #$_facturaId (${_formatearFecha(_fechaFactura!.toLocal())}). Descarga disponible con los importes originales, sin modificar registros.",
              style: const TextStyle(fontSize: 12.5, color: _grisTexto),
              textAlign: TextAlign.center,
            ),
          ] else if (_ventaGuardada) ...[
            const SizedBox(height: 10),
            Text(
              "Venta registrada (Factura #$_facturaId). Puedes volver a descargar el PDF sin duplicar el registro.",
              style: const TextStyle(fontSize: 12.5, color: _grisTexto),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _fila(
    String texto,
    double valor, {
    bool bold = false,
    String prefijo = '',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              color: bold ? _negroElegante : _grisTexto,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "${prefijo}Lps ${valor.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 14.5,
            color: _negroElegante,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
