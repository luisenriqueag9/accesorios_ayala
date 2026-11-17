import 'dart:typed_data';

/// Implementación de respaldo para plataformas sin `dart.library.js_interop`.
String? crearBlobUrlVideo(Uint8List bytes, String contentType) => null;

/// Operación inocua en plataformas sin soporte Web.
void revocarBlobUrlVideo(String? url) {}
