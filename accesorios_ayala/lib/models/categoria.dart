class Categoria {
  final String id;
  final String nombre;
  final int orden;
  final bool visible;

  Categoria({
    required this.id,
    required this.nombre,
    required this.orden,
    this.visible = true,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'nombre': nombre, 'orden': orden, 'visible': visible};
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    final ordenRaw = map['orden'];
    final orden = ordenRaw is num
        ? ordenRaw.toInt()
        : int.tryParse('${ordenRaw ?? ''}') ?? 0;
    final visibleRaw = map['visible'];
    final visible = visibleRaw is bool ? visibleRaw : true;

    return Categoria(
      id: (map['id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      orden: orden,
      visible: visible,
    );
  }
}
