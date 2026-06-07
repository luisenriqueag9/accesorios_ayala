import 'dart:ui';
import 'package:accesorios_ayala/services/pdf_service_web.dart';
import 'package:accesorios_ayala/utils/open_pdf_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/descargar_pdf_web.dart';
import '../models/venta.dart';
import '../controllers/venta_controller.dart';

import '../models/cliente.dart';
import '../models/producto.dart';
import '../utils/widgets/glass_container.dart';
import '../utils/theme.dart';

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
  final impuestoCtrl = TextEditingController(text: "0");

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
    final total = subtotal + impuesto;

    return Scaffold(
      appBar: AppBar(title: const Text("Vista previa del recibo")),
      body: Stack(
        children: [
          _fondoDegradado(),
          _fondoBlur(),

          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= CLIENTE =================
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Cliente",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text("Nombre: ${widget.cliente.nombre}"),
                      Text("Teléfono: ${widget.cliente.telefono}"),
                      Text("Dirección: ${widget.cliente.direccion}"),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ================= PRODUCTOS =================
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Productos",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 10),

                      ...widget.seleccionados.map((item) {
                        final p = item["producto"] as Producto;
                        final c = item["cantidad"] as int;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    p.imageUrl != null && p.imageUrl!.isNotEmpty
                                    ? Image.network(
                                        p.imageUrl!,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return const Icon(
                                            Icons.image,
                                            size: 40,
                                          );
                                        },
                                      )
                                    : const Icon(Icons.image, size: 40),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "Cantidad: $c",
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Text(
                                "Lps ${(p.precio * c).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ================= RESUMEN =================
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Resumen",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoOscuro,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _fila("Subtotal:", subtotal),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("ISV (%):"),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: impuestoCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      _fila("Impuesto:", impuesto),

                      const Divider(height: 20),
                      _fila("TOTAL:", total, bold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ================= PDF =================
                ElevatedButton(
                  onPressed: () async {
                    try {
                      debugPrint("👉 Iniciando generación de PDF");

                      final bytes = await PdfWebService.generarReciboPro(
                        cliente: widget.cliente,
                        seleccionados: widget.seleccionados,
                        impuestoPorcentaje:
                            double.tryParse(impuestoCtrl.text) ?? 0,
                      );

                      final venta = Venta(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        clienteId: widget.cliente.id,
                        clienteNombre: widget.cliente.nombre,
                        fecha: DateTime.now(),
                        subtotal: subtotal,
                        impuesto: impuesto,
                        total: total,
                      );

                      await VentaController.guardarVenta(venta);

                      debugPrint(
                        "✅ PDF generado correctamente (${bytes.length} bytes)",
                      );

                      descargarPdfWeb(
                        bytes,
                        'Recibo_AccesoriosAyala_${DateTime.now().millisecondsSinceEpoch}.pdf',
                      );
                    } catch (e, s) {
                      debugPrint("❌ ERROR al descargar PDF");
                      debugPrint(e.toString());
                      debugPrint(s.toString());

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error al descargar el PDF"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primario,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Descargar PDF"),
                ),
              ],
            ),
          ),
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
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          "Lps ${valor.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

/// FONDO
Widget _fondoDegradado() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFE1F5FE), Color(0xFFCCF2F7), Colors.white],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  );
}

Widget _fondoBlur() {
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: Container(color: Colors.white10),
  );
}
