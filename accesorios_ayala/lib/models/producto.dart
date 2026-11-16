class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String? imageUrl;
  final bool visibleCatalogo;

  /// IDs de documentos de la colección `categorias` a los que pertenece el
  /// producto. Lista inmodificable; vacía por defecto.
  final List<String> categoriaIds;

  Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    this.imageUrl,
    this.visibleCatalogo = true,
    List<String> categoriaIds = const [],
  }) : categoriaIds = List<String>.unmodifiable(categoriaIds);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imageUrl': imageUrl,
      'visibleCatalogo': visibleCatalogo,
      'categoriaIds': List<String>.of(categoriaIds),
    };
  }

  /// Normaliza el valor crudo de `categoriaIds` leído desde Firestore:
  /// ignora elementos que no sean String o queden vacíos tras `trim()`,
  /// elimina duplicados y conserva el orden de aparición.
  static List<String> _leerCategoriaIds(dynamic raw) {
    if (raw is! List) return const [];

    final vistos = <String>{};
    final resultado = <String>[];
    for (final elemento in raw) {
      if (elemento is! String) continue;
      final limpio = elemento.trim();
      if (limpio.isEmpty) continue;
      if (vistos.add(limpio)) resultado.add(limpio);
    }
    return resultado;
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
      categoriaIds: _leerCategoriaIds(map['categoriaIds']),
    );
  }
}
