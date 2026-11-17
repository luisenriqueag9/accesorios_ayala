import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../controllers/banner_controller.dart';
import '../models/banner_config.dart';

typedef SeleccionImagenBanner = ({
  Uint8List bytes,
  String contentType,
  String nombre,
});

class _CarruselItemBorrador {
  final String id;
  String? url;
  final Uint8List? bytes;
  final String? contentType;
  final String? nombre;

  _CarruselItemBorrador({
    required this.id,
    this.url,
    this.bytes,
    this.contentType,
    this.nombre,
  });

  bool get tieneUrlGuardada => url != null && url!.trim().isNotEmpty;
  bool get estaPendienteSubida => !tieneUrlGuardada && bytes != null;
}

/// Vista administrativa integrada para consultar y guardar la configuración
/// básica del banner multimedia del catálogo público.
class GestionBannerView extends StatefulWidget {
  final bool integrado;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [BannerController.cargarConfiguracion].
  final Future<BannerConfig> Function()? onCargarConfiguracion;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [BannerController.guardarConfiguracion].
  final Future<BannerConfig> Function(
    BannerConfig config, {
    required DateTime? updatedAtEsperado,
  })? onGuardarConfiguracion;

  /// Inyección opcional para pruebas. Si es `null` se usa [FilePicker].
  final Future<SeleccionImagenBanner?> Function()? onSeleccionarImagen;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [BannerController.subirImagenBanner].
  final Future<String> Function({
    required Uint8List bytes,
    required String contentType,
    bool esCarrusel,
  })? onSubirImagen;

  const GestionBannerView({
    super.key,
    this.integrado = false,
    this.onCargarConfiguracion,
    this.onGuardarConfiguracion,
    this.onSeleccionarImagen,
    this.onSubirImagen,
  });

  @override
  State<GestionBannerView> createState() => _GestionBannerViewState();
}

class _GestionBannerViewState extends State<GestionBannerView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  BannerConfig _configOriginal = BannerConfig.inicial();
  BannerConfig _borrador = BannerConfig.inicial();
  final List<_CarruselItemBorrador> _carruselBorrador = [];
  Uint8List? _imagenPendienteBytes;
  String? _imagenPendienteContentType;
  String? _imagenPendienteNombre;
  String? _imagenPendienteUrlSubida;
  int _contadorCarruselLocal = 0;
  bool _cargando = true;
  bool _guardando = false;
  String _textoProgresoGuardado = 'Guardando...';
  String? _errorCarga;

  bool get _tieneImagenPendiente =>
      _imagenPendienteBytes != null || _imagenPendienteUrlSubida != null;

  bool get _haySubidasPendientesDeGuardar =>
      _imagenPendienteUrlSubida != null ||
      _carruselBorrador.any(
        (item) => item.tieneUrlGuardada && item.bytes != null,
      );

  bool get _carruselModificado {
    if (_carruselBorrador.length != _configOriginal.carrusel.length) {
      return true;
    }
    for (var i = 0; i < _carruselBorrador.length; i++) {
      final borradorItem = _carruselBorrador[i];
      final originalItem = _configOriginal.carrusel[i];
      if (borradorItem.estaPendienteSubida ||
          borradorItem.id != originalItem.id ||
          borradorItem.url != originalItem.url) {
        return true;
      }
    }
    return false;
  }

  bool get _hayCambios {
    return _tieneImagenPendiente ||
        _carruselModificado ||
        _borrador.activo != _configOriginal.activo ||
        _borrador.modo != _configOriginal.modo ||
        _borrador.intervaloSegundos != _configOriginal.intervaloSegundos;
  }

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  String _mensajeErrorAmigable(Object error, {required String accion}) {
    if (error is BannerConflictoConcurrenciaException) {
      return error.mensaje;
    }
    if (error is ArgumentError) {
      return error.message?.toString() ??
          'Los datos del banner no son válidos.';
    }
    if (error is StateError) {
      return error.message;
    }
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
        case 'unauthenticated':
          return 'No tienes permisos suficientes para $accion la configuración del banner.';
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          return 'Error de conexión con Firestore. Verifica tu internet e intenta nuevamente.';
        default:
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'No se pudo $accion la configuración del banner.';
      }
    }
    return 'Ocurrió un error inesperado al $accion la configuración del banner.';
  }

  void _mostrarSnackBar(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red.shade700 : const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _cargarConfiguracion() async {
    if (_guardando) return;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final cargador =
          widget.onCargarConfiguracion ?? BannerController.cargarConfiguracion;
      final config = await cargador();
      if (!mounted) return;

      final borradorInicial = config.tieneContenidoParaModoActivo
          ? config
          : config.copyWith(activo: false);

      setState(() {
        _configOriginal = config;
        _borrador = borradorInicial;
        _reconstruirCarruselDesdeConfig(config);
        _limpiarBorradorImagenPendiente();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = _mensajeErrorAmigable(e, accion: 'cargar');
        _cargando = false;
      });
    }
  }

  void _limpiarBorradorImagenPendiente() {
    _imagenPendienteBytes = null;
    _imagenPendienteContentType = null;
    _imagenPendienteNombre = null;
    _imagenPendienteUrlSubida = null;
  }

  void _reconstruirCarruselDesdeConfig(BannerConfig config) {
    _carruselBorrador
      ..clear()
      ..addAll(
        config.carrusel
            .take(BannerController.maxItemsCarrusel)
            .map((item) => _CarruselItemBorrador(id: item.id, url: item.url)),
      );
  }

  List<BannerCarruselItem> _convertirCarruselBorradorParaGuardar() {
    final resultado = <BannerCarruselItem>[];
    for (final item in _carruselBorrador) {
      if (!item.tieneUrlGuardada) continue;
      if (resultado.length >= BannerController.maxItemsCarrusel) break;
      resultado.add(
        BannerCarruselItem(
          id: item.id,
          url: item.url!.trim(),
          orden: resultado.length,
        ),
      );
    }
    return resultado;
  }

  void _descartarImagenPendiente() {
    if (_cargando || _guardando || !_tieneImagenPendiente) return;
    setState(_limpiarBorradorImagenPendiente);
  }

  String? _inferirMimeImagen(String? nombreArchivo, String? extension) {
    final extRaw = (extension ?? '').trim().toLowerCase();
    final ext = extRaw.isNotEmpty
        ? extRaw
        : (nombreArchivo != null && nombreArchivo.contains('.')
              ? nombreArchivo.split('.').last.trim().toLowerCase()
              : '');

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  /// Abre el selector de archivos, valida formato/tamaño con
  /// [BannerController.validarImagenBanner] y devuelve la imagen lista en
  /// memoria sin subirla a Firebase. Devuelve `null` únicamente si el usuario
  /// cancela la selección.
  Future<SeleccionImagenBanner?> _seleccionarYValidarImagenLocal() async {
    final SeleccionImagenBanner? seleccion;
    if (widget.onSeleccionarImagen != null) {
      seleccion = await widget.onSeleccionarImagen!();
    } else {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (resultado == null || resultado.files.isEmpty) {
        return null;
      }

      final archivo = resultado.files.single;
      final bytes = archivo.bytes;
      if (bytes == null) {
        throw StateError(
          'No se pudo leer el contenido de la imagen seleccionada.',
        );
      }

      final mime = _inferirMimeImagen(archivo.name, archivo.extension);
      if (mime == null) {
        throw ArgumentError(
          'Formato de imagen no permitido. Usa JPEG, PNG o WebP.',
        );
      }

      seleccion = (bytes: bytes, contentType: mime, nombre: archivo.name);
    }

    if (seleccion == null) return null;

    final mimeNormalizado = seleccion.contentType.trim().toLowerCase();
    BannerController.validarImagenBanner(
      bytes: seleccion.bytes,
      contentType: mimeNormalizado,
    );

    return (
      bytes: seleccion.bytes,
      contentType: mimeNormalizado,
      nombre: seleccion.nombre,
    );
  }

  Future<void> _seleccionarImagenFija() async {
    if (_cargando || _guardando) return;

    try {
      final seleccion = await _seleccionarYValidarImagenLocal();
      if (seleccion == null || !mounted) return;

      setState(() {
        _imagenPendienteBytes = seleccion.bytes;
        _imagenPendienteContentType = seleccion.contentType;
        _imagenPendienteNombre = seleccion.nombre;
        _imagenPendienteUrlSubida = null;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar(
        _mensajeErrorAmigable(e, accion: 'validar la imagen'),
        esError: true,
      );
    }
  }

  String _generarIdCarruselUnico() {
    _contadorCarruselLocal = (_contadorCarruselLocal + 1) % 100000;
    return 'car_${DateTime.now().millisecondsSinceEpoch}_$_contadorCarruselLocal';
  }

  Future<void> _agregarImagenCarrusel() async {
    if (_cargando || _guardando) return;

    if (_carruselBorrador.length >= BannerController.maxItemsCarrusel) {
      _mostrarSnackBar(
        'El carrusel admite como máximo ${BannerController.maxItemsCarrusel} imágenes.',
        esError: true,
      );
      return;
    }

    try {
      final seleccion = await _seleccionarYValidarImagenLocal();
      if (seleccion == null || !mounted) return;

      setState(() {
        _carruselBorrador.add(
          _CarruselItemBorrador(
            id: _generarIdCarruselUnico(),
            bytes: seleccion.bytes,
            contentType: seleccion.contentType,
            nombre: seleccion.nombre,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar(
        _mensajeErrorAmigable(e, accion: 'validar la imagen'),
        esError: true,
      );
    }
  }

  void _moverImagenCarrusel(int indice, int delta) {
    if (_cargando || _guardando) return;
    final nuevoIndice = indice + delta;
    if (indice < 0 ||
        indice >= _carruselBorrador.length ||
        nuevoIndice < 0 ||
        nuevoIndice >= _carruselBorrador.length) {
      return;
    }

    setState(() {
      final item = _carruselBorrador.removeAt(indice);
      _carruselBorrador.insert(nuevoIndice, item);
    });
  }

  void _quitarImagenCarrusel(int indice) {
    if (_cargando || _guardando) return;
    if (indice < 0 || indice >= _carruselBorrador.length) return;

    setState(() {
      _carruselBorrador.removeAt(indice);
      final quedanGuardadas = _carruselBorrador.any(
        (item) => item.tieneUrlGuardada,
      );
      if (!quedanGuardadas && _borrador.modo == ModoBannerCatalogo.carrusel) {
        _borrador = _borrador.copyWith(activo: false);
      }
    });
  }

  void _cambiarModo(ModoBannerCatalogo nuevoModo) {
    if (_cargando || _guardando || _borrador.modo == nuevoModo) return;

    final candidato = _borrador.copyWith(modo: nuevoModo);
    setState(() {
      _borrador = candidato.tieneContenidoParaModoActivo
          ? candidato
          : candidato.copyWith(activo: false);
    });
  }

  void _cambiarEstadoActivo(bool activar) {
    if (_cargando || _guardando) return;

    if (activar && !_borrador.tieneContenidoParaModoActivo) {
      setState(() {
        _borrador = _borrador.copyWith(activo: false);
      });
      _mostrarSnackBar(
        'No se puede activar el banner porque el modo "${_borrador.modo.etiqueta}" aún no tiene contenido publicado.',
        esError: true,
      );
      return;
    }

    setState(() {
      _borrador = _borrador.copyWith(activo: activar);
    });
  }

  void _cambiarIntervalo(int nuevoIntervalo) {
    if (_cargando || _guardando) return;
    final ajustado = nuevoIntervalo.clamp(
      BannerConfig.intervaloMinimoSegundos,
      BannerConfig.intervaloMaximoSegundos,
    );
    if (ajustado == _borrador.intervaloSegundos) return;

    setState(() {
      _borrador = _borrador.copyWith(intervaloSegundos: ajustado);
    });
  }

  Future<void> _confirmarDescartarORecargar() async {
    if (_cargando || _guardando) return;

    if (_haySubidasPendientesDeGuardar) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Descartar cambios'),
            content: const Text(
              'Ya se subieron imágenes a Firebase Storage en un intento anterior sin completar el guardado en Firestore. Si descartas ahora, esos archivos permanecerán en Storage sin referencia en el catálogo.\n\n¿Deseas descartar los cambios y recargar la configuración vigente?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(foregroundColor: _rojoMarca),
                child: const Text('Descartar y recargar'),
              ),
            ],
          );
        },
      );
      if (confirmar != true || !mounted) return;
    }

    await _cargarConfiguracion();
  }

  Future<void> _guardarConfiguracion() async {
    if (_cargando || _guardando) return;

    final pendientesCarrusel = _carruselBorrador
        .where((item) => item.estaPendienteSubida)
        .toList();

    setState(() {
      _guardando = true;
      if (_imagenPendienteBytes != null && _imagenPendienteUrlSubida == null) {
        _textoProgresoGuardado = 'Subiendo imagen...';
      } else if (pendientesCarrusel.isNotEmpty) {
        _textoProgresoGuardado =
            'Subiendo imagen 1 de ${pendientesCarrusel.length}...';
      } else {
        _textoProgresoGuardado = 'Guardando...';
      }
    });

    try {
      final subidor =
          widget.onSubirImagen ??
          ({
            required Uint8List bytes,
            required String contentType,
            bool esCarrusel = false,
          }) => BannerController.subirImagenBanner(
            bytes: bytes,
            contentType: contentType,
            esCarrusel: esCarrusel,
          );

      String? urlImagenFinal = _borrador.imagenUrl;

      if (_imagenPendienteUrlSubida != null) {
        urlImagenFinal = _imagenPendienteUrlSubida;
      } else if (_imagenPendienteBytes != null &&
          _imagenPendienteContentType != null) {
        final urlSubida = await subidor(
          bytes: _imagenPendienteBytes!,
          contentType: _imagenPendienteContentType!,
          esCarrusel: false,
        );
        if (!mounted) return;

        // Conserva la URL subida para reutilizarla si falla Firestore y el usuario reintenta.
        _imagenPendienteUrlSubida = urlSubida;
        urlImagenFinal = urlSubida;
      }

      for (var i = 0; i < pendientesCarrusel.length; i++) {
        final item = pendientesCarrusel[i];
        setState(() {
          _textoProgresoGuardado =
              'Subiendo imagen ${i + 1} de ${pendientesCarrusel.length}...';
        });

        final urlSubida = await subidor(
          bytes: item.bytes!,
          contentType: item.contentType!,
          esCarrusel: true,
        );
        if (!mounted) return;

        // Guarda de inmediato la URL en el borrador local para no duplicar subidas al reintentar.
        item.url = urlSubida;
      }

      if (_carruselBorrador.any((item) => !item.tieneUrlGuardada)) {
        throw StateError(
          'No todas las imágenes del carrusel cuentan con una URL válida.',
        );
      }

      setState(() {
        _textoProgresoGuardado = 'Guardando configuración...';
      });

      final carruselFinal = _convertirCarruselBorradorParaGuardar();
      final candidato = _borrador.copyWith(
        imagenUrl: urlImagenFinal,
        carrusel: carruselFinal,
      );
      final configAGuardar = candidato.tieneContenidoParaModoActivo
          ? candidato
          : candidato.copyWith(activo: false);

      final guardador =
          widget.onGuardarConfiguracion ??
          (BannerConfig config, {required DateTime? updatedAtEsperado}) =>
              BannerController.guardarConfiguracion(
                config,
                updatedAtEsperado: updatedAtEsperado,
              );

      final guardada = await guardador(
        configAGuardar,
        updatedAtEsperado: _configOriginal.updatedAt,
      );
      if (!mounted) return;

      setState(() {
        _configOriginal = guardada;
        _borrador = guardada;
        _reconstruirCarruselDesdeConfig(guardada);
        _limpiarBorradorImagenPendiente();
        _guardando = false;
      });
      _mostrarSnackBar('Configuración del banner guardada correctamente.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
      });
      _mostrarSnackBar(
        _mensajeErrorAmigable(e, accion: 'guardar'),
        esError: true,
      );
    }
  }

  Widget _construirTarjetaBase({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bordeSuave),
        boxShadow: [
          BoxShadow(
            color: _rojoMarca.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _construirEncabezado(bool esEscritorio) {
    return _construirTarjetaBase(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _rosaSuave,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _bordeSuave),
            ),
            child: const Icon(
              Icons.view_carousel_outlined,
              color: _rojoMarca,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Banner del catálogo',
                  style: TextStyle(
                    fontSize: esEscritorio ? 21 : 18,
                    fontWeight: FontWeight.w800,
                    color: _negroElegante,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Administra el estado de publicación, el modo activo y el intervalo del carrusel.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _grisTexto,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirAvisoBannerEstatico() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _rosaSuave,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeSuave),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _rojoMarca, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'El catálogo público continuará mostrando el banner estático actual hasta que se integre la carga dinámica en una etapa posterior.',
              style: TextStyle(
                fontSize: 13,
                color: _negroElegante,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoCarga() {
    return _construirTarjetaBase(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _rojoMarca),
            SizedBox(height: 14),
            Text(
              'Cargando configuración del banner...',
              style: TextStyle(
                fontSize: 14,
                color: _grisTexto,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirEstadoError() {
    return _construirTarjetaBase(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: _rojoMarca,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _errorCarga ?? 'No se pudo cargar la configuración del banner.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: _negroElegante,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarConfiguracion,
              style: ElevatedButton.styleFrom(
                backgroundColor: _rojoMarca,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSeccionPublicacion() {
    final tieneContenido = _borrador.tieneContenidoParaModoActivo;

    return _construirTarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _rojoMarca,
            title: const Text(
              'Banner multimedia activo',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: _negroElegante,
              ),
            ),
            subtitle: Text(
              _borrador.activo
                  ? 'Habilitado para mostrarse cuando el catálogo público integre el banner dinámico.'
                  : 'Desactivado. Se conservará el banner estático de respaldo.',
              style: const TextStyle(fontSize: 13, color: _grisTexto),
            ),
            value: _borrador.activo,
            onChanged: _guardando ? null : _cambiarEstadoActivo,
          ),
          if (!tieneContenido) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF57C00),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El modo "${_borrador.modo.etiqueta}" no tiene contenido cargado todavía. Permanecerá desactivado hasta que se agreguen archivos en una etapa posterior.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _negroElegante,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirSelectorModo() {
    return _construirTarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Modo activo del banner',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Solo un modo puede estar activo a la vez. Cambiar de modo conserva los recursos ya guardados en los demás modos.',
            style: TextStyle(fontSize: 13, color: _grisTexto),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ModoBannerCatalogo.values.map((modo) {
              final seleccionado = _borrador.modo == modo;
              return ChoiceChip(
                label: Text(modo.etiqueta),
                selected: seleccionado,
                selectedColor: _rosaSuave,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: seleccionado ? _rojoMarca : _bordeSuave,
                  width: seleccionado ? 1.5 : 1,
                ),
                labelStyle: TextStyle(
                  color: seleccionado ? _rojoMarca : _negroElegante,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: _guardando ? null : (_) => _cambiarModo(modo),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionImagenFija() {
    final tieneGuardada =
        _borrador.imagenUrl != null && _borrador.imagenUrl!.isNotEmpty;
    final tienePendiente = _imagenPendienteBytes != null;

    return _construirTarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Imagen fija del banner',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
              ),
              if (tienePendiente)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Text(
                    _imagenPendienteUrlSubida != null
                        ? 'Subida pendiente de guardar'
                        : 'Vista previa sin guardar',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100),
                    ),
                  ),
                )
              else if (tieneGuardada)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Imagen guardada',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Formatos permitidos: JPEG, PNG o WebP (máximo 5 MB). La imagen se subirá al pulsar Guardar cambios.',
            style: TextStyle(fontSize: 13, color: _grisTexto),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: _rosaSuave,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _bordeSuave),
              ),
              child: tienePendiente
                  ? Image.memory(
                      _imagenPendienteBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : tieneGuardada
                  ? Image.network(
                      _borrador.imagenUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: _rojoMarca),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No se pudo cargar la vista previa de la imagen guardada.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: _grisTexto),
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: _rojoMarca,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No hay ninguna imagen seleccionada.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: _grisTexto,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (tienePendiente && _imagenPendienteNombre != null) ...[
            const SizedBox(height: 8),
            Text(
              'Archivo seleccionado: $_imagenPendienteNombre',
              style: const TextStyle(
                fontSize: 12.5,
                color: _grisTexto,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _guardando ? null : _seleccionarImagenFija,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _rojoMarca,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  tienePendiente || tieneGuardada
                      ? 'Reemplazar imagen'
                      : 'Seleccionar imagen',
                ),
              ),
              if (_tieneImagenPendiente)
                OutlinedButton.icon(
                  onPressed: _guardando ? null : _descartarImagenPendiente,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _negroElegante,
                    side: const BorderSide(color: _bordeSuave),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Descartar selección'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionCarrusel() {
    final alcanzoMaximo =
        _carruselBorrador.length >= BannerController.maxItemsCarrusel;

    return _construirTarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Imágenes del carrusel',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _rosaSuave,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _bordeSuave),
                ),
                child: Text(
                  '${_carruselBorrador.length} / ${BannerController.maxItemsCarrusel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _rojoMarca,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Agrega hasta 15 imágenes (JPEG, PNG o WebP, máx. 5 MB c/u) y ordénalas antes de guardar.',
            style: TextStyle(fontSize: 13, color: _grisTexto),
          ),
          const SizedBox(height: 14),
          if (_carruselBorrador.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: _rosaSuave,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _bordeSuave),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.collections_outlined,
                    size: 38,
                    color: _rojoMarca,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aún no hay imágenes en el carrusel.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _grisTexto,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _carruselBorrador.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _construirItemCarrusel(_carruselBorrador[i], i),
                ],
              ],
            ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: (_guardando || alcanzoMaximo)
                ? null
                : _agregarImagenCarrusel,
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              alcanzoMaximo ? 'Límite de 15 imágenes alcanzado' : 'Agregar imagen',
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirItemCarrusel(_CarruselItemBorrador item, int indice) {
    final esPendiente = item.estaPendienteSubida;
    final formato = item.contentType
        ?.replaceFirst('image/', '')
        .toUpperCase();

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeSuave),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _rosaSuave,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${indice + 1}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: _rojoMarca,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 54,
              child: esPendiente
                  ? Image.memory(item.bytes!, fit: BoxFit.cover)
                  : item.tieneUrlGuardada
                  ? Image.network(
                      item.url!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _rojoMarca,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: _rosaSuave,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 20,
                          color: _grisTexto,
                        ),
                      ),
                    )
                  : Container(
                      color: _rosaSuave,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: _grisTexto,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre?.trim().isNotEmpty == true
                      ? item.nombre!
                      : 'Imagen ${indice + 1}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: esPendiente
                            ? const Color(0xFFFFF8E1)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        esPendiente ? 'Pendiente de subida' : 'Guardada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: esPendiente
                              ? const Color(0xFFE65100)
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    if (formato != null && formato.isNotEmpty)
                      Text(
                        formato,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _grisTexto,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: (_guardando || indice == 0)
                ? null
                : () => _moverImagenCarrusel(indice, -1),
            icon: const Icon(Icons.arrow_upward_rounded, size: 19),
            color: _negroElegante,
            tooltip: 'Subir una posición',
          ),
          IconButton(
            onPressed: (_guardando || indice == _carruselBorrador.length - 1)
                ? null
                : () => _moverImagenCarrusel(indice, 1),
            icon: const Icon(Icons.arrow_downward_rounded, size: 19),
            color: _negroElegante,
            tooltip: 'Bajar una posición',
          ),
          IconButton(
            onPressed: _guardando ? null : () => _quitarImagenCarrusel(indice),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: _rojoMarca,
            tooltip: 'Quitar imagen',
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoContenidoModos() {
    final tieneImagen =
        _borrador.imagenUrl != null && _borrador.imagenUrl!.isNotEmpty;
    final cantidadCarrusel = _borrador.carrusel.length;
    final tieneVideo =
        _borrador.videoUrl != null && _borrador.videoUrl!.isNotEmpty;

    return _construirTarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contenido guardado por modo',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 12),
          _construirFilaEstadoModo(
            icono: Icons.image_outlined,
            titulo: ModoBannerCatalogo.imagen.etiqueta,
            detalle: tieneImagen
                ? 'Imagen configurada'
                : 'Sin imagen configurada',
            disponible: tieneImagen,
            activo: _borrador.modo == ModoBannerCatalogo.imagen,
          ),
          const Divider(height: 20, color: _bordeSuave),
          _construirFilaEstadoModo(
            icono: Icons.collections_outlined,
            titulo: ModoBannerCatalogo.carrusel.etiqueta,
            detalle: cantidadCarrusel > 0
                ? '$cantidadCarrusel ${cantidadCarrusel == 1 ? 'imagen configurada' : 'imágenes configuradas'}'
                : 'Sin imágenes en el carrusel',
            disponible: cantidadCarrusel > 0,
            activo: _borrador.modo == ModoBannerCatalogo.carrusel,
          ),
          const Divider(height: 20, color: _bordeSuave),
          _construirFilaEstadoModo(
            icono: Icons.videocam_outlined,
            titulo: ModoBannerCatalogo.video.etiqueta,
            detalle: tieneVideo
                ? 'Video configurado'
                : 'Sin video configurado',
            disponible: tieneVideo,
            activo: _borrador.modo == ModoBannerCatalogo.video,
          ),
        ],
      ),
    );
  }

  Widget _construirFilaEstadoModo({
    required IconData icono,
    required String titulo,
    required String detalle,
    required bool disponible,
    required bool activo,
  }) {
    return Row(
      children: [
        Icon(icono, color: activo ? _rojoMarca : _grisTexto, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: activo ? _rojoMarca : _negroElegante,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: const TextStyle(fontSize: 12.5, color: _grisTexto),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: disponible ? const Color(0xFFE8F5E9) : _rosaSuave,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            disponible ? 'Con contenido' : 'Sin contenido',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: disponible ? const Color(0xFF2E7D32) : _grisTexto,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirControlIntervalo() {
    return _construirTarjetaBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Intervalo de transición del carrusel',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
              ),
              Text(
                '${_borrador.intervaloSegundos} s',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _rojoMarca,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tiempo entre cada diapositiva cuando el modo carrusel esté activo (2 a 30 segundos).',
            style: TextStyle(fontSize: 13, color: _grisTexto),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: _guardando ||
                        _borrador.intervaloSegundos <=
                            BannerConfig.intervaloMinimoSegundos
                    ? null
                    : () => _cambiarIntervalo(_borrador.intervaloSegundos - 1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: _rojoMarca,
                tooltip: 'Disminuir intervalo',
              ),
              Expanded(
                child: Slider(
                  value: _borrador.intervaloSegundos.toDouble(),
                  min: BannerConfig.intervaloMinimoSegundos.toDouble(),
                  max: BannerConfig.intervaloMaximoSegundos.toDouble(),
                  divisions: BannerConfig.intervaloMaximoSegundos -
                      BannerConfig.intervaloMinimoSegundos,
                  activeColor: _rojoMarca,
                  label: '${_borrador.intervaloSegundos} s',
                  onChanged: _guardando
                      ? null
                      : (valor) => _cambiarIntervalo(valor.round()),
                ),
              ),
              IconButton(
                onPressed: _guardando ||
                        _borrador.intervaloSegundos >=
                            BannerConfig.intervaloMaximoSegundos
                    ? null
                    : () => _cambiarIntervalo(_borrador.intervaloSegundos + 1),
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: _rojoMarca,
                tooltip: 'Aumentar intervalo',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirBarraAcciones() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: _guardando ? null : _confirmarDescartarORecargar,
          style: OutlinedButton.styleFrom(
            foregroundColor: _negroElegante,
            side: const BorderSide(color: _bordeSuave),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Descartar / Recargar'),
        ),
        ElevatedButton.icon(
          onPressed: (_cargando || _guardando || !_hayCambios)
              ? null
              : _guardarConfiguracion,
          style: ElevatedButton.styleFrom(
            backgroundColor: _rojoMarca,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_guardando ? _textoProgresoGuardado : 'Guardar cambios'),
        ),
      ],
    );
  }

  Widget _construirContenido(bool esEscritorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _construirEncabezado(esEscritorio),
        const SizedBox(height: 16),
        _construirAvisoBannerEstatico(),
        const SizedBox(height: 16),
        if (_cargando)
          _construirEstadoCarga()
        else if (_errorCarga != null)
          _construirEstadoError()
        else ...[
          _construirSeccionPublicacion(),
          const SizedBox(height: 16),
          _construirSelectorModo(),
          const SizedBox(height: 16),
          if (_borrador.modo == ModoBannerCatalogo.imagen) ...[
            _construirSeccionImagenFija(),
            const SizedBox(height: 16),
          ] else if (_borrador.modo == ModoBannerCatalogo.carrusel) ...[
            _construirSeccionCarrusel(),
            const SizedBox(height: 16),
          ],
          _construirEstadoContenidoModos(),
          const SizedBox(height: 16),
          if (_borrador.modo == ModoBannerCatalogo.carrusel) ...[
            _construirControlIntervalo(),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: _construirBarraAcciones(),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esEscritorio = constraints.maxWidth >= 700;
        final contenido = _construirContenido(esEscritorio);

        if (widget.integrado) {
          return contenido;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _rojoMarca),
            title: const Text(
              'Banner del catálogo',
              style: TextStyle(
                color: _rojoMarca,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(esEscritorio ? 24 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: contenido,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
