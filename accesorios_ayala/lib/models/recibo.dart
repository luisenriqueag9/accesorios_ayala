import 'package:accesorios_ayala/models/cliente.dart';
import 'package:accesorios_ayala/models/producto.dart';

class ReciboItem {
  final Producto producto;
  final int cantidad;

  ReciboItem({
    required this.producto,
    required this.cantidad,
  });

  double get total => cantidad * producto.precio;
}

class Recibo {
  final Cliente cliente;
  final List<ReciboItem> items;
  final double impuesto; // % editable (ejemplo: 0, 15)

  Recibo({
    required this.cliente,
    required this.items,
    required this.impuesto,
  });

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.total);

  double get impuestoCalculado =>
      subtotal * (impuesto / 100);

  double get totalGeneral =>
      subtotal + impuestoCalculado;
}
