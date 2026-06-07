class Venta {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final DateTime fecha;
  final double subtotal;
  final double impuesto;
  final double total;

  Venta({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.fecha,
    required this.subtotal,
    required this.impuesto,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'fecha': fecha.toIso8601String(),
      'subtotal': subtotal,
      'impuesto': impuesto,
      'total': total,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'] ?? '',
      clienteId: map['clienteId'] ?? '',
      clienteNombre: map['clienteNombre'] ?? '',
      fecha: DateTime.parse(map['fecha']),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      impuesto: (map['impuesto'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
    );
  }
}