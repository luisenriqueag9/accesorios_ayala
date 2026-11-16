import 'package:cloud_firestore/cloud_firestore.dart';

/// Modos disponibles para el banner multimedia del catálogo público.
/// Solo puede haber un modo activo a la vez.
enum ModoBannerCatalogo {
  imagen('imagen', 'Imagen fija'),
  carrusel('carrusel', 'Carrusel de imágenes'),
  video('video', 'Video');

  final String valorFirestore;
  final String etiqueta;

  const ModoBannerCatalogo(this.valorFirestore, this.etiqueta);

  /// Convierte un valor crudo (por ejemplo de Firestore) a [ModoBannerCatalogo].
  /// Si el valor es nulo o desconocido, devuelve [ModoBannerCatalogo.imagen].
  static ModoBannerCatalogo fromValor(dynamic valor) {
    if (valor is String) {
      final normalizado = valor.trim().toLowerCase();
      for (final modo in ModoBannerCatalogo.values) {
        if (modo.valorFirestore == normalizado) return modo;
      }
    }
    return ModoBannerCatalogo.imagen;
  }
}

/// Elemento individual dentro del carrusel de imágenes del banner.
class BannerCarruselItem {
  final String id;
  final String url;
  final int orden;

  const BannerCarruselItem({
    required this.id,
    required this.url,
    this.orden = 0,
  });

  bool get tieneUrlValida => _esUrlMultimediaValida(url);

  BannerCarruselItem copyWith({
    String? id,
    String? url,
    int? orden,
  }) {
    return BannerCarruselItem(
      id: id ?? this.id,
      url: url ?? this.url,
      orden: orden ?? this.orden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.trim(),
      'url': url.trim(),
      'orden': orden,
    };
  }

  factory BannerCarruselItem.fromMap(Map<String, dynamic> map) {
    final idRaw = map['id'];
    final urlRaw = map['url'];

    return BannerCarruselItem(
      id: idRaw is String ? idRaw.trim() : '${idRaw ?? ''}'.trim(),
      url: urlRaw is String ? urlRaw.trim() : '',
      orden: _parsearEntero(map['orden'], defecto: 0),
    );
  }
}

/// Configuración del banner multimedia administrable del catálogo público.
class BannerConfig {
  static const int intervaloMinimoSegundos = 2;
  static const int intervaloMaximoSegundos = 30;
  static const int intervaloPorDefectoSegundos = 5;

  final bool activo;
  final ModoBannerCatalogo modo;
  final String? imagenUrl;
  final String? videoUrl;
  final List<BannerCarruselItem> carrusel;
  final int intervaloSegundos;
  final DateTime? updatedAt;

  BannerConfig({
    this.activo = false,
    this.modo = ModoBannerCatalogo.imagen,
    String? imagenUrl,
    String? videoUrl,
    List<BannerCarruselItem> carrusel = const [],
    int intervaloSegundos = intervaloPorDefectoSegundos,
    DateTime? updatedAt,
  })  : imagenUrl = _normalizarUrlOpcional(imagenUrl),
        videoUrl = _normalizarUrlOpcional(videoUrl),
        carrusel = List<BannerCarruselItem>.unmodifiable(
          _normalizarCarrusel(carrusel),
        ),
        intervaloSegundos = _normalizarIntervalo(intervaloSegundos),
        updatedAt = updatedAt?.toUtc();

  /// Configuración inicial sin contenido publicado y desactivada.
  factory BannerConfig.inicial() {
    return BannerConfig(
      activo: false,
      modo: ModoBannerCatalogo.imagen,
      imagenUrl: null,
      videoUrl: null,
      carrusel: const [],
      intervaloSegundos: intervaloPorDefectoSegundos,
      updatedAt: null,
    );
  }

  /// Indica si el modo actualmente seleccionado cuenta con al menos un recurso válido.
  bool get tieneContenidoParaModoActivo {
    switch (modo) {
      case ModoBannerCatalogo.imagen:
        return imagenUrl != null && imagenUrl!.isNotEmpty;
      case ModoBannerCatalogo.carrusel:
        return carrusel.any((item) => item.tieneUrlValida);
      case ModoBannerCatalogo.video:
        return videoUrl != null && videoUrl!.isNotEmpty;
    }
  }

  /// Indica si el banner está activo y tiene contenido válido para su modo actual.
  bool get debeMostrarse => activo && tieneContenidoParaModoActivo;

  BannerConfig copyWith({
    bool? activo,
    ModoBannerCatalogo? modo,
    String? imagenUrl,
    bool limpiarImagenUrl = false,
    String? videoUrl,
    bool limpiarVideoUrl = false,
    List<BannerCarruselItem>? carrusel,
    int? intervaloSegundos,
    DateTime? updatedAt,
    bool limpiarUpdatedAt = false,
  }) {
    return BannerConfig(
      activo: activo ?? this.activo,
      modo: modo ?? this.modo,
      imagenUrl: limpiarImagenUrl ? null : (imagenUrl ?? this.imagenUrl),
      videoUrl: limpiarVideoUrl ? null : (videoUrl ?? this.videoUrl),
      carrusel: carrusel ?? this.carrusel,
      intervaloSegundos: intervaloSegundos ?? this.intervaloSegundos,
      updatedAt: limpiarUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activo': activo,
      'modo': modo.valorFirestore,
      'imagenUrl': imagenUrl,
      'videoUrl': videoUrl,
      'carrusel': carrusel.map((item) => item.toMap()).toList(),
      'intervaloSegundos': intervaloSegundos,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory BannerConfig.fromMap(Map<String, dynamic> map) {
    final activoRaw = map['activo'];
    final activo = activoRaw is bool ? activoRaw : false;

    final carruselRaw = map['carrusel'];
    final itemsCarrusel = <BannerCarruselItem>[];
    if (carruselRaw is List) {
      for (final elemento in carruselRaw) {
        if (elemento is! Map) continue;
        if (elemento.keys.any((k) => k is! String)) continue;
        final mapaElemento = <String, dynamic>{
          for (final entry in elemento.entries) entry.key as String: entry.value,
        };
        final item = BannerCarruselItem.fromMap(mapaElemento);
        if (item.tieneUrlValida) {
          itemsCarrusel.add(item);
        }
      }
    }

    final intervaloRaw = map['intervaloSegundos'];
    final intervaloParseado = _parsearEnteroNullable(intervaloRaw);

    return BannerConfig(
      activo: activo,
      modo: ModoBannerCatalogo.fromValor(map['modo']),
      imagenUrl: _normalizarUrlOpcional(map['imagenUrl']),
      videoUrl: _normalizarUrlOpcional(map['videoUrl']),
      carrusel: itemsCarrusel,
      intervaloSegundos: intervaloParseado ?? intervaloPorDefectoSegundos,
      updatedAt: _parsearFecha(map['updatedAt']),
    );
  }

  static String? _normalizarUrlOpcional(dynamic raw) {
    if (raw is! String) return null;
    final limpia = raw.trim();
    return _esUrlMultimediaValida(limpia) ? limpia : null;
  }

  static int _normalizarIntervalo(int valor) {
    if (valor <= 0) return intervaloPorDefectoSegundos;
    if (valor < intervaloMinimoSegundos) return intervaloMinimoSegundos;
    if (valor > intervaloMaximoSegundos) return intervaloMaximoSegundos;
    return valor;
  }

  static List<BannerCarruselItem> _normalizarCarrusel(
    List<BannerCarruselItem> items,
  ) {
    final idsVistos = <String>{};
    final filtrados = <BannerCarruselItem>[];

    for (final item in items) {
      if (!item.tieneUrlValida) continue;
      final idLimpio = item.id.trim();
      if (idLimpio.isNotEmpty && !idsVistos.add(idLimpio)) {
        continue;
      }
      filtrados.add(
        BannerCarruselItem(
          id: idLimpio,
          url: item.url.trim(),
          orden: item.orden,
        ),
      );
    }

    filtrados.sort((a, b) {
      final ordenCmp = a.orden.compareTo(b.orden);
      if (ordenCmp != 0) return ordenCmp;

      final idCmp = a.id.compareTo(b.id);
      if (idCmp != 0) return idCmp;

      return a.url.compareTo(b.url);
    });

    return filtrados;
  }
}

bool _esUrlMultimediaValida(String url) {
  final limpia = url.trim();
  if (limpia.isEmpty) return false;
  final uri = Uri.tryParse(limpia);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  return (scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty;
}

int _parsearEntero(dynamic valor, {required int defecto}) {
  return _parsearEnteroNullable(valor) ?? defecto;
}

int? _parsearEnteroNullable(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor.trim());
  return null;
}

DateTime? _parsearFecha(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor.toUtc();
  if (valor is Timestamp) return valor.toDate().toUtc();
  if (valor is int) {
    return DateTime.fromMillisecondsSinceEpoch(valor, isUtc: true);
  }
  if (valor is String && valor.trim().isNotEmpty) {
    return DateTime.tryParse(valor.trim())?.toUtc();
  }
  return null;
}
