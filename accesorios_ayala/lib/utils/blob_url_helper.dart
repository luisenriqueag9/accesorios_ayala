import 'dart:typed_data';

import 'blob_url_helper_stub.dart'
    if (dart.library.js_interop) 'blob_url_helper_web.dart'
    as impl;

/// Crea una URL temporal `blob:` en Flutter Web a partir de [bytes] y
/// [contentType]. En plataformas sin soporte Web devuelve `null`.
String? crearBlobUrlVideo(Uint8List bytes, String contentType) {
  return impl.crearBlobUrlVideo(bytes, contentType);
}

/// Revoca una URL temporal `blob:` creada previamente. No realiza ninguna acción
/// si [url] es `null`, está vacía o la plataforma no es Web.
void revocarBlobUrlVideo(String? url) {
  impl.revocarBlobUrlVideo(url);
}
