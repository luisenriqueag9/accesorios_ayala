import 'dart:ui';
import 'package:accesorios_ayala/services/pdf_service_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/descargar_pdf_web.dart';
import '../models/venta.dart';
import '../controllers/venta_controller.dart';

import '../models/cliente.dart';
import '../models/producto.dart';

class VistaPreviaReciboView extends StatefulWidget {
  final Cliente cliente;
  final List<Map<String, dynamic>> seleccionados;

  const VistaPreviaReciboView({
    super.key,
    required this.cliente,
    required this.seleccionados,
  });

  @override
  State<VistaPreviaReciboView> createState() => _VistaPreviaReciboViewState();
}

class _VistaPreviaReciboViewState extends State<VistaPreviaReciboView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  final impuestoCtrl = TextEditingController(text: "0");
  final envioCtrl = TextEditingController(text: "120.00");

  bool _procesandoPdf = false;
  bool _ventaGuardada = false;
  String? _facturaId;
  DateTime? _fechaFactura;
  Uint8List? _pdfBytesEmitido;

  @override
  void dispose() {
    impuestoCtrl.dispose();
    envioCtrl.dispose();
    super.dispose();
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
    final subtotal = calcularSubtotal();

    final impuestoPorcentaje =
        double.tryParse(impuestoCtrl.text.isEmpty ? "0" : impuestoCtrl.text) ??
        0;

    final impuesto = subtotal * (impuestoPorcentaje / 100);
    final costoEnvio = _parsearEnvio();
    final total = subtotal + impuesto + costoEnvio;

    return Scaffold(
      backgroundColor: _rosaSuave,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _rojoMarca),
        shape: const Border(bottom: BorderSide(color: _bordeSuave, width: 1)),
        title: const Text(
          "Vista previa del recibo",
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
                  child: LayoutBuilder(
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
                          impuesto: impuesto,
                          costoEnvio: costoEnvio,
                          total: total,
                        ),
                      );

                      final seccionBotonPdf = _construirBotonDescargar(
                        context: context,
                        subtotal: subtotal,
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
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirTituloSeccion(Icons.person_outline_rounded, "Cliente"),
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
        enabled: !_ventaGuardada && !_procesandoPdf,
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
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _construirResumenFinanciero({
    required double subtotal,
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
            const Text(
              "ISV (%):",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _grisTexto,
              ),
            ),
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
            const Text(
              "Costo de envío (L.):",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _grisTexto,
              ),
            ),
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

  Widget _construirBotonDescargar({
    required BuildContext context,
    required double subtotal,
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

                      _facturaId ??= DateTime.now().millisecondsSinceEpoch
                          .toString();
                      _fechaFactura ??= DateTime.now();

                      final bytes =
                          _pdfBytesEmitido ??
                          await PdfWebService.generarReciboPro(
                            cliente: widget.cliente,
                            seleccionados: widget.seleccionados,
                            impuestoPorcentaje: impuestoPorcentaje,
                            envio: costoEnvio,
                            facturaNumero: _facturaId,
                            fechaEmision: _fechaFactura,
                          );

                      if (!_ventaGuardada) {
                        final venta = Venta(
                          id: _facturaId!,
                          clienteId: widget.cliente.id,
                          clienteNombre: widget.cliente.nombre,
                          fecha: _fechaFactura!,
                          subtotal: subtotal,
                          impuesto: impuesto,
                          total: total,
                          envio: costoEnvio,
                        );

                        await VentaController.guardarVenta(venta);

                        if (mounted) {
                          setState(() {
                            _ventaGuardada = true;
                            _pdfBytesEmitido = bytes;
                          });
                        } else {
                          _ventaGuardada = true;
                          _pdfBytesEmitido = bytes;
                        }
                      }

                      debugPrint(
                        "✅ PDF generado correctamente (${bytes.length} bytes)",
                      );

                      descargarPdfWeb(
                        bytes,
                        'Recibo_AccesoriosAyala_${_facturaId!}.pdf',
                      );
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
                  : (_ventaGuardada
                        ? "Volver a descargar PDF"
                        : "Descargar PDF"),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          if (_ventaGuardada) ...[
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

  Widget _fila(String texto, double valor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            color: bold ? _negroElegante : _grisTexto,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        Text(
          "Lps ${valor.toStringAsFixed(2)}",
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
