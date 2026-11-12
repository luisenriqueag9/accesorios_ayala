class Categoria {
  final String id;
  final String nombre;
  final int orden;

  Categoria({required this.id, required this.nombre, required this.orden});

  Map<String, dynamic> toMap() {
    return {'id': id, 'nombre': nombre, 'orden': orden};
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    final ordenRaw = map['orden'];
    final orden = ordenRaw is num
        ? ordenRaw.toInt()
        : int.tryParse('${ordenRaw ?? ''}') ?? 0;

    return Categoria(
      id: (map['id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      orden: orden,
    );
  }
}
