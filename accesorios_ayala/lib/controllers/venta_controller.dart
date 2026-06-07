import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/venta.dart';

class VentaController {
  static final _firestore = FirebaseFirestore.instance;

  static const String collection = 'ventas';

  static Future<void> guardarVenta(Venta venta) async {
    await _firestore.collection(collection).doc(venta.id).set(venta.toMap());
  }

  static Future<List<Venta>> cargarVentas() async {
    final snapshot = await _firestore.collection(collection).get();

    return snapshot.docs.map((doc) {
      return Venta.fromMap(doc.data());
    }).toList();
  }

  static Future<double> ventasMesActual() async {
    final ventas = await cargarVentas();

    final ahora = DateTime.now();

    double total = 0;

    for (final venta in ventas) {
      if (venta.fecha.year == ahora.year && venta.fecha.month == ahora.month) {
        total += venta.total;
      }
    }

    return total;
  }

  static Future<int> cantidadFacturasMes() async {
    final ventas = await cargarVentas();

    final ahora = DateTime.now();

    return ventas.where((venta) {
      return venta.fecha.year == ahora.year && venta.fecha.month == ahora.month;
    }).length;
  }

  static Future<double> ventasHoy() async {
    final ventas = await cargarVentas();

    final hoy = DateTime.now();

    double total = 0;

    for (final venta in ventas) {
      if (venta.fecha.year == hoy.year &&
          venta.fecha.month == hoy.month &&
          venta.fecha.day == hoy.day) {
        total += venta.total;
      }
    }

    return total;
  }

  static Future<List<Map<String, dynamic>>> topClientes() async {
    final ventas = await cargarVentas();

    final Map<String, double> acumulado = {};

    for (final venta in ventas) {
      acumulado[venta.clienteNombre] =
          (acumulado[venta.clienteNombre] ?? 0) + venta.total;
    }

    final resultado = acumulado.entries.map((e) {
      return {'cliente': e.key, 'total': e.value};
    }).toList();

    resultado.sort(
      (a, b) => (b['total'] as double).compareTo(a['total'] as double),
    );

    return resultado.take(5).toList();
  }
}
