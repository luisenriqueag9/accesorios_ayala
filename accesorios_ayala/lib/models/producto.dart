class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String? imageUrl;
  final bool visibleCatalogo;

  Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    this.imageUrl,
    this.visibleCatalogo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imageUrl': imageUrl,
      'visibleCatalogo': visibleCatalogo,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    final visibleRaw = map['visibleCatalogo'];

    return Producto(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      precio: (map['precio'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      visibleCatalogo: visibleRaw is bool ? visibleRaw : true,
    );
  }
}
