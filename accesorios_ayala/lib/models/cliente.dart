class Cliente {
  final String id;
  final String nombre;
  final String telefono;
  final String direccion;
  final String departamento;

  Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.departamento,
  });

  factory Cliente.fromMap(Map<String, dynamic> map, {required String id}) {
    return Cliente(
      id: id,
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'] ?? '',
      direccion: map['direccion'] ?? '',
      departamento: map['departamento'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'direccion': direccion,
      'departamento': departamento,
    };
  }
}
