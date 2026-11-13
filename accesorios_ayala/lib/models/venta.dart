class Venta {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final DateTime fecha;
  final double subtotal;
  final double impuesto;
  final double total;
  final double envio;
  final bool descuentoMayoristaActivo;
  final double descuentoPorcentaje;
  final double descuentoMonto;

  Venta({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.fecha,
    required this.subtotal,
    required this.impuesto,
    required this.total,
    this.envio = 0.0,
    this.descuentoMayoristaActivo = false,
    this.descuentoPorcentaje = 0.0,
    this.descuentoMonto = 0.0,
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
      'envio': envio,
      'descuentoMayoristaActivo': descuentoMayoristaActivo,
      'descuentoPorcentaje': descuentoPorcentaje,
      'descuentoMonto': descuentoMonto,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'] ?? '',
      clienteId: map['clienteId'] ?? '',
      clienteNombre: map['clienteNombre'] ?? '',
      fecha: DateTime.parse(map['fecha']),
      subtotal: _toDouble(map['subtotal']),
      impuesto: _toDouble(map['impuesto']),
      total: _toDouble(map['total']),
      envio: _toDouble(map['envio']),
      descuentoMayoristaActivo: map['descuentoMayoristaActivo'] == true,
      descuentoPorcentaje: _toDouble(map['descuentoPorcentaje']),
      descuentoMonto: _toDouble(map['descuentoMonto']),
    );
  }
}
