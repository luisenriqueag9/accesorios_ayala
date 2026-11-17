import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Crea una URL temporal `blob:` en el navegador a partir de [bytes] y
/// [contentType] sin almacenar referencias globales.
String? crearBlobUrlVideo(Uint8List bytes, String contentType) {
  final mime = contentType.trim().toLowerCase();
  if (bytes.isEmpty || mime.isEmpty) return null;

  final blob = web.Blob(
    <web.BlobPart>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  return web.URL.createObjectURL(blob);
}

/// Revoca una URL temporal `blob:` previamente generada con
/// [crearBlobUrlVideo].
void revocarBlobUrlVideo(String? url) {
  final limpia = url?.trim();
  if (limpia == null || !limpia.startsWith('blob:')) return;
  web.URL.revokeObjectURL(limpia);
}
