import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/banner_config.dart';
import 'auth_controller.dart';

/// Excepción lanzada cuando otro administrador modificó la configuración del
/// banner antes de confirmar los cambios actuales.
class BannerConflictoConcurrenciaException implements Exception {
  final String mensaje;

  const BannerConflictoConcurrenciaException([
    this.mensaje =
        'Otro administrador actualizó el banner recientemente. Recarga la configuración antes de guardar.',
  ]);

  @override
  String toString() => mensaje;
}

/// Controlador para leer, validar, subir medios y guardar la configuración del
/// banner multimedia en Firestore y Firebase Storage.
class BannerController {
  static const String collection = 'configuracion_catalogo';
  static const String documentId = 'banner';
  static const String storageBucket = 'accesorios-ayala.firebasestorage.app';

  static const int maxBytesImagen = 5 * 1024 * 1024;
  static const int maxBytesVideo = 20 * 1024 * 1024;
  static const int maxItemsCarrusel = 15;
  static const int maxLongitudIdCarrusel = 80;
  static const int maxLongitudUrl = 2048;

  static const Map<String, String> _extensionesImagen = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  static const Map<String, String> _extensionesVideo = {
    'video/mp4': 'mp4',
    'video/webm': 'webm',
  };

  static final Random _random = Random();
  static int _contadorSecuencial = 0;

  /// Lee `configuracion_catalogo/banner` desde Firestore. Si el documento no
  /// existe, devuelve [BannerConfig.inicial].
  static Future<BannerConfig> cargarConfiguracion({
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final snapshot = await db.collection(collection).doc(documentId).get();

    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return BannerConfig.inicial();
    }

    return BannerConfig.fromMap(data);
  }

  /// Valida bytes y tipo MIME de una imagen antes de subirla a Storage.
  /// Devuelve la extensión normalizada (`jpg`, `png` o `webp`).
  static String validarImagenBanner({
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.isEmpty) {
      throw ArgumentError('La imagen seleccionada está vacía.');
    }
    if (bytes.length > maxBytesImagen) {
      throw ArgumentError(
        'La imagen supera el tamaño máximo permitido de 5 MB.',
      );
    }

    final mimeNormalizado = contentType.trim().toLowerCase();
    final extension = _extensionesImagen[mimeNormalizado];
    if (extension == null) {
      throw ArgumentError(
        'Formato de imagen no permitido ($contentType). Usa JPEG, PNG o WebP.',
      );
    }
    return extension;
  }

  /// Valida bytes y tipo MIME de un video antes de subirlo a Storage.
  /// Devuelve la extensión normalizada (`mp4` o `webm`).
  static String validarVideoBanner({
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.isEmpty) {
      throw ArgumentError('El video seleccionado está vacío.');
    }
    if (bytes.length > maxBytesVideo) {
      throw ArgumentError(
        'El video supera el tamaño máximo permitido de 20 MB.',
      );
    }

    final mimeNormalizado = contentType.trim().toLowerCase();
    final extension = _extensionesVideo[mimeNormalizado];
    if (extension == null) {
      throw ArgumentError(
        'Formato de video no permitido ($contentType). Usa MP4 o WebM.',
      );
    }
    return extension;
  }

  /// Valida que [config] cumpla las reglas publicadas de Firestore antes de
  /// iniciar la transacción de guardado.
  static void validarConfiguracionParaGuardar(BannerConfig config) {
    if (config.intervaloSegundos < BannerConfig.intervaloMinimoSegundos ||
        config.intervaloSegundos > BannerConfig.intervaloMaximoSegundos) {
      throw ArgumentError(
        'El intervalo del carrusel debe estar entre '
        '${BannerConfig.intervaloMinimoSegundos} y '
        '${BannerConfig.intervaloMaximoSegundos} segundos.',
      );
    }

    if (config.imagenUrl != null &&
        !_esUrlStorageBannerValida(config.imagenUrl!, 'imagen')) {
      throw ArgumentError(
        'La URL de imagen debe pertenecer a banner/imagen/ del proyecto.',
      );
    }

    if (config.videoUrl != null &&
        !_esUrlStorageBannerValida(config.videoUrl!, 'video')) {
      throw ArgumentError(
        'La URL de video debe pertenecer a banner/video/ del proyecto.',
      );
    }

    if (config.carrusel.length > maxItemsCarrusel) {
      throw ArgumentError(
        'El carrusel admite como máximo $maxItemsCarrusel imágenes.',
      );
    }

    for (final item in config.carrusel) {
      final idLimpio = item.id.trim();
      if (idLimpio.isEmpty || idLimpio.length > maxLongitudIdCarrusel) {
        throw ArgumentError(
          'Cada elemento del carrusel debe tener un identificador válido '
          '(entre 1 y $maxLongitudIdCarrusel caracteres).',
        );
      }
      if (item.orden < 0) {
        throw ArgumentError(
          'El orden de cada elemento del carrusel debe ser mayor o igual a 0.',
        );
      }
      if (!_esUrlStorageBannerValida(item.url, 'carrusel')) {
        throw ArgumentError(
          'Cada imagen del carrusel debe pertenecer a banner/carrusel/ del proyecto.',
        );
      }
    }
  }

  /// Sube una imagen a `banner/imagen/` o `banner/carrusel/` con nombre único
  /// usando la sesión administrativa actual y devuelve su URL de descarga.
  static Future<String> subirImagenBanner({
    required Uint8List bytes,
    required String contentType,
    bool esCarrusel = false,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) async {
    _asegurarAdminAutorizado(auth);

    final mimeNormalizado = contentType.trim().toLowerCase();
    final extension = validarImagenBanner(
      bytes: bytes,
      contentType: mimeNormalizado,
    );

    final carpeta = esCarrusel ? 'carrusel' : 'imagen';
    final ruta = 'banner/$carpeta/${_generarNombreUnico(extension)}';
    final ref = (storage ?? FirebaseStorage.instance).ref().child(ruta);

    await ref.putData(bytes, SettableMetadata(contentType: mimeNormalizado));
    return ref.getDownloadURL();
  }

  /// Sube un video a `banner/video/` con nombre único usando la sesión
  /// administrativa actual y devuelve su URL de descarga.
  static Future<String> subirVideoBanner({
    required Uint8List bytes,
    required String contentType,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) async {
    _asegurarAdminAutorizado(auth);

    final mimeNormalizado = contentType.trim().toLowerCase();
    final extension = validarVideoBanner(
      bytes: bytes,
      contentType: mimeNormalizado,
    );

    final ruta = 'banner/video/${_generarNombreUnico(extension)}';
    final ref = (storage ?? FirebaseStorage.instance).ref().child(ruta);

    await ref.putData(bytes, SettableMetadata(contentType: mimeNormalizado));
    return ref.getDownloadURL();
  }

  /// Guarda [config] en `configuracion_catalogo/banner` dentro de una
  /// transacción verificando [updatedAtEsperado] para evitar sobrescrituras
  /// concurrentes entre administradores.
  ///
  /// Para documentos inexistentes se debe pasar `updatedAtEsperado: null`.
  static Future<BannerConfig> guardarConfiguracion(
    BannerConfig config, {
    required DateTime? updatedAtEsperado,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) async {
    _asegurarAdminAutorizado(auth);
    validarConfiguracionParaGuardar(config);

    final db = firestore ?? FirebaseFirestore.instance;
    final docRef = db.collection(collection).doc(documentId);
    final esperadoUtc = updatedAtEsperado?.toUtc();

    final payload = <String, dynamic>{
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        if (esperadoUtc != null) {
          throw const BannerConflictoConcurrenciaException(
            'La configuración esperada ya no existe en el servidor. Recarga antes de guardar.',
          );
        }
      } else {
        final dataActual = snapshot.data();
        final actualUpdatedAt = dataActual == null
            ? null
            : BannerConfig.fromMap(dataActual).updatedAt;

        if (esperadoUtc == null ||
            actualUpdatedAt == null ||
            !actualUpdatedAt.isAtSameMomentAs(esperadoUtc)) {
          throw const BannerConflictoConcurrenciaException();
        }
      }

      transaction.set(docRef, payload);
    });

    final actualizado = await docRef.get();
    final dataActualizada = actualizado.data();
    if (!actualizado.exists || dataActualizada == null) {
      return config;
    }

    final configLeida = BannerConfig.fromMap(dataActualizada);
    if (!_coincideConConfigGuardada(configLeida, config)) {
      throw const BannerConflictoConcurrenciaException(
        'Otro administrador modificó el banner inmediatamente después de guardar. Recarga la configuración para ver la versión vigente.',
      );
    }
    return configLeida;
  }

  static bool _coincideConConfigGuardada(
    BannerConfig leida,
    BannerConfig escrita,
  ) {
    if (leida.activo != escrita.activo ||
        leida.modo != escrita.modo ||
        leida.imagenUrl != escrita.imagenUrl ||
        leida.videoUrl != escrita.videoUrl ||
        leida.intervaloSegundos != escrita.intervaloSegundos ||
        leida.carrusel.length != escrita.carrusel.length) {
      return false;
    }
    for (var i = 0; i < leida.carrusel.length; i++) {
      final a = leida.carrusel[i];
      final b = escrita.carrusel[i];
      if (a.id != b.id || a.url != b.url || a.orden != b.orden) {
        return false;
      }
    }
    return true;
  }

  static void _asegurarAdminAutorizado(FirebaseAuth? auth) {
    final usuario = (auth ?? FirebaseAuth.instance).currentUser;
    if (!AuthController.esAdminAutorizado(usuario)) {
      throw StateError(
        'Se requiere una sesión administrativa autorizada para modificar el banner.',
      );
    }
  }

  static String _generarNombreUnico(String extension) {
    _contadorSecuencial = (_contadorSecuencial + 1) % 100000;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sufijoAleatorio =
        _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${timestamp}_${_contadorSecuencial}_$sufijoAleatorio.$extension';
  }

  static bool _esUrlStorageBannerValida(String url, String carpeta) {
    final limpia = url.trim();
    if (limpia.isEmpty || limpia.length > maxLongitudUrl) return false;

    final carpetaEscapada = RegExp.escape(carpeta);
    final patron = RegExp(
      r'^https://firebasestorage\.googleapis\.com/v0/b/accesorios-ayala\.firebasestorage\.app/o/banner%2F' +
          carpetaEscapada +
          r'%2F[^/?#\s]+(\?[^\s]*)?$',
    );
    return patron.hasMatch(limpia);
  }
}
