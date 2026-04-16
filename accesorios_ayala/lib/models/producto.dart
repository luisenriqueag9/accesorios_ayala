import 'dart:convert';
import 'dart:typed_data';

class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;

  // iOS / Desktop (ruta local del archivo)
  final String? imagenPath;

  // Web (imagen en Base64)
  final String? imagenBase64;

  Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    this.imagenPath,
    this.imagenBase64,
  });

  /// 👉 Devuelve bytes de imagen (para Image.memory)
  Uint8List? get imagenBytes {
    if (imagenBase64 == null || imagenBase64!.isEmpty) return null;
    return base64Decode(imagenBase64!);
  }

  /// 👉 Saber si la imagen es local (archivo)
  bool get tieneImagenLocal => imagenPath != null && imagenPath!.isNotEmpty;

  /// 👉 Saber si la imagen es Base64 (web)
  bool get tieneImagenBase64 => imagenBase64 != null && imagenBase64!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'imagenPath': imagenPath,
      'imagenBase64': imagenBase64,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      precio: (map['precio'] ?? 0).toDouble(),
      imagenPath: map['imagenPath'],
      imagenBase64: map['imagenBase64'],
    );
  }
}
