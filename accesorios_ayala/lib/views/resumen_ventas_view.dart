import 'package:flutter/material.dart';
import '../controllers/venta_controller.dart';

class ResumenVentasView extends StatefulWidget {
  final bool integrado;

  const ResumenVentasView({super.key, this.integrado = false});

  @override
  State<ResumenVentasView> createState() => _ResumenVentasViewState();
}

class _ResumenVentasViewState extends State<ResumenVentasView> {
  double ventasHoy = 0;
  double ventasMes = 0;
  int facturasMes = 0;

  List<Map<String, dynamic>> topClientes = [];

  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    ventasHoy = await VentaController.ventasHoy();
    ventasMes = await VentaController.ventasMesActual();
    facturasMes = await VentaController.cantidadFacturasMes();
    topClientes = await VentaController.topClientes();

    if (!mounted) return;
    setState(() {
      cargando = false;
    });
  }

  Widget tarjeta({
    required IconData icono,
    required String titulo,
    required String valor,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icono, color: color, size: 30),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    valor,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _construirContenidoVentas() {
    return [
      tarjeta(
        icono: Icons.today,
        titulo: "Ventas de hoy",
        valor: "L. ${ventasHoy.toStringAsFixed(2)}",
        color: Colors.orange,
      ),
      const SizedBox(height: 15),
      tarjeta(
        icono: Icons.attach_money,
        titulo: "Ventas del mes",
        valor: "L. ${ventasMes.toStringAsFixed(2)}",
        color: Colors.green,
      ),
      const SizedBox(height: 15),
      tarjeta(
        icono: Icons.receipt_long,
        titulo: "Facturas emitidas",
        valor: facturasMes.toString(),
        color: Colors.blue,
      ),
      const SizedBox(height: 25),
      const Text(
        "🏆 Top Clientes",
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      ...topClientes.asMap().entries.map((entry) {
        final index = entry.key;
        final cliente = entry.value;

        String medalla = "🏅";

        if (index == 0) medalla = "🥇";
        if (index == 1) medalla = "🥈";
        if (index == 2) medalla = "🥉";

        return Card(
          child: ListTile(
            leading: Text(medalla, style: const TextStyle(fontSize: 24)),
            title: Text(
              cliente['cliente'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: Text(
              "L. ${(cliente['total'] as double).toStringAsFixed(2)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.integrado) {
      if (cargando) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Resumen de Ventas",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202020),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar resumen',
                onPressed: () {
                  setState(() {
                    cargando = true;
                  });
                  cargarDatos();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._construirContenidoVentas(),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Resumen de Ventas")),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: _construirContenidoVentas(),
              ),
            ),
    );
  }
}
