import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../controllers/banner_controller.dart';
import '../controllers/categoria_controller.dart';
import '../controllers/producto_controller.dart';
import '../models/banner_config.dart';
import '../models/categoria.dart';
import '../models/producto.dart';

/// Devuelve los productos que deben mostrarse en el catálogo público:
/// solo los que tienen `visibleCatalogo == true`, filtrados opcionalmente por
/// [categoriaId] y, si [consulta] no está vacía, cuyo nombre o descripción la
/// contengan (sin distinguir mayúsculas). Conserva el orden original, no
/// duplica productos y no modifica la lista recibida.
List<Producto> filtrarProductosCatalogo(
  List<Producto> productos,
  String consulta, {
  String? categoriaId,
}) {
  final texto = consulta.trim().toLowerCase();
  final categoria = categoriaId?.trim();
  final tieneCategoria = categoria != null && categoria.isNotEmpty;

  return productos.where((p) {
    if (!p.visibleCatalogo) return false;
    if (tieneCategoria && !p.categoriaIds.contains(categoria)) return false;
    if (texto.isEmpty) return true;
    return p.nombre.toLowerCase().contains(texto) ||
        p.descripcion.toLowerCase().contains(texto);
  }).toList();
}

/// Devuelve las categorías visibles ordenadas según el orden administrativo
/// (`orden`, `nombre` sin distinguir mayúsculas e `id`), sin modificar la lista
/// recibida.
List<Categoria> prepararCategoriasCatalogo(List<Categoria> categorias) {
  final visibles = categorias.where((c) => c.visible).toList();
  visibles.sort((a, b) {
    final ordenCmp = a.orden.compareTo(b.orden);
    if (ordenCmp != 0) return ordenCmp;

    final nombreCmp = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    if (nombreCmp != 0) return nombreCmp;

    return a.id.compareTo(b.id);
  });
  return visibles;
}

class CatalogoPublicoView extends StatefulWidget {
  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [ProductoController.cargarProductos].
  final Future<List<Producto>> Function()? cargarProductos;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [CategoriaController.cargarCategorias] con `soloVisibles: true`.
  final Future<List<Categoria>> Function()? cargarCategorias;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [BannerController.cargarConfiguracion].
  final Future<BannerConfig> Function()? cargarBanner;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [VideoPlayerController.networkUrl].
  final VideoPlayerController Function(Uri uri)? crearControladorVideo;

  /// Inyección opcional para pruebas. Si es `null` se usa [VideoPlayer].
  final Widget Function(VideoPlayerController controller)? construirVistaVideo;

  const CatalogoPublicoView({
    super.key,
    this.cargarProductos,
    this.cargarCategorias,
    this.cargarBanner,
    this.crearControladorVideo,
    this.construirVistaVideo,
  });

  @override
  State<CatalogoPublicoView> createState() => _CatalogoPublicoViewState();
}

class _CatalogoPublicoViewState extends State<CatalogoPublicoView> {
  // Paleta de identidad visual — Boutique Accesorios Ayala
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _blanco = Color(0xFFFFFFFF);
  static const Color _rosaClaro = Color(0xFFFFF1F1);
  static const Color _fondoPagina = Color(0xFFFFFAFA);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF2E1E2);

  // Paleta de portada premium (negro profundo, dorado y champán)
  static const Color _negroPortada = Color(0xFF0B0B0B);
  static const Color _negroSuperficie = Color(0xFF141414);
  static const Color _doradoElegante = Color(0xFFC5A46D);
  static const Color _champan = Color(0xFFF2E5C9);

  final TextEditingController _buscarCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _claveSeccionProductos = GlobalKey();

  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  bool _cargando = true;
  String? _errorCarga;

  // Estado independiente para categorías visibles y filtro seleccionado.
  List<Categoria> _categorias = [];
  bool _cargandoCategorias = true;
  String? _errorCategorias;
  String? _categoriaSeleccionadaId;

  // Estado independiente para la configuración del banner.
  BannerConfig _bannerConfig = BannerConfig.inicial();
  // ignore: unused_field
  bool _cargandoBanner = true;
  PageController? _carruselPageCtrl;
  Timer? _timerCarrusel;
  int _indiceCarruselActual = 0;
  bool _animandoCarrusel = false;
  VideoPlayerController? _videoBannerController;
  String? _videoBannerUrl;
  bool _videoBannerListo = false;
  int _tokenVideoBanner = 0;
  final Expando<bool> _videosBannerDispuestos = Expando<bool>(
    'videosBannerDispuestos',
  );

  bool get _hayProductosVisibles => _productos.any((p) => p.visibleCatalogo);

  // Estado local en memoria para el carrito de compras (identificado por ID)
  final Map<String, Producto> _productosCarrito = {};
  final Map<String, int> _cantidadesCarrito = {};

  int get _totalUnidadesCarrito =>
      _cantidadesCarrito.values.fold(0, (suma, cant) => suma + cant);

  double get _totalPrecioCarrito {
    double total = 0;
    _cantidadesCarrito.forEach((id, cantidad) {
      final producto = _productosCarrito[id];
      if (producto != null && cantidad > 0) {
        total += producto.precio * cantidad;
      }
    });
    return total;
  }

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _cargarCategorias();
    _cargarBanner();
  }

  @override
  void dispose() {
    _detenerTimerCarrusel();
    _liberarVideoBanner();
    final controller = _carruselPageCtrl;
    _carruselPageCtrl = null;
    controller?.dispose();
    _buscarCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _irAProductos() {
    final contextoSeccion = _claveSeccionProductos.currentContext;
    if (contextoSeccion != null) {
      Scrollable.ensureVisible(
        contextoSeccion,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        240,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final lista = await (widget.cargarProductos ??
          ProductoController.cargarProductos)();
      if (!mounted) return;

      setState(() {
        _productos = lista;
        _productosFiltrados = _calcularProductosFiltrados();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = 'No se pudieron cargar los productos en este momento.';
        _cargando = false;
      });
    }
  }

  /// Carga (o reintenta cargar) las categorías visibles de forma independiente
  /// a los productos, manteniendo su propio estado de carga y error.
  Future<void> _cargarCategorias() async {
    setState(() {
      _cargandoCategorias = true;
      _errorCategorias = null;
    });

    try {
      final lista = await (widget.cargarCategorias ??
          () => CategoriaController.cargarCategorias(soloVisibles: true))();
      if (!mounted) return;

      final preparadas = prepararCategoriasCatalogo(lista);
      setState(() {
        _categorias = preparadas;
        _cargandoCategorias = false;
        if (_categoriaSeleccionadaId != null &&
            !preparadas.any((c) => c.id == _categoriaSeleccionadaId)) {
          _categoriaSeleccionadaId = null;
          _productosFiltrados = _calcularProductosFiltrados();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCategorias =
            'No se pudieron cargar las categorías en este momento.';
        _cargandoCategorias = false;
      });
    }
  }

  List<BannerCarruselItem> get _itemsCarruselActivos {
    if (!_bannerConfig.debeMostrarse ||
        _bannerConfig.modo != ModoBannerCatalogo.carrusel) {
      return const [];
    }
    return _bannerConfig.carrusel
        .where((item) => item.tieneUrlValida)
        .toList();
  }

  void _detenerTimerCarrusel() {
    _timerCarrusel?.cancel();
    _timerCarrusel = null;
  }

  void _configurarCarrusel() {
    _detenerTimerCarrusel();
    _indiceCarruselActual = 0;

    final items = _itemsCarruselActivos;
    if (items.isEmpty) {
      final controllerAnterior = _carruselPageCtrl;
      _carruselPageCtrl = null;
      _animandoCarrusel = false;
      controllerAnterior?.dispose();
      return;
    }

    if (_carruselPageCtrl == null) {
      _carruselPageCtrl = PageController(initialPage: 0);
      _animandoCarrusel = false;
    } else if (_carruselPageCtrl!.hasClients) {
      _carruselPageCtrl!.jumpToPage(0);
    }

    if (items.length <= 1) return;

    _timerCarrusel = Timer.periodic(
      Duration(seconds: _bannerConfig.intervaloSegundos),
      (_) => _avanzarCarrusel(),
    );
  }

  Future<void> _avanzarCarrusel() async {
    if (!mounted || _animandoCarrusel) return;
    final items = _itemsCarruselActivos;
    final controller = _carruselPageCtrl;
    if (items.length <= 1 || controller == null || !controller.hasClients) {
      return;
    }

    final siguiente = (_indiceCarruselActual + 1) % items.length;
    _animandoCarrusel = true;
    try {
      await controller.animateToPage(
        siguiente,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      if (!mounted || !identical(controller, _carruselPageCtrl)) return;
    } catch (_) {
      // Ignora interrupciones si el controlador se desmontó durante la animación.
    } finally {
      if (identical(controller, _carruselPageCtrl)) {
        _animandoCarrusel = false;
      }
    }
  }

  Future<void> _disponerControladorVideoSeguro(
    VideoPlayerController controller,
  ) async {
    if (_videosBannerDispuestos[controller] == true) return;
    _videosBannerDispuestos[controller] = true;
    try {
      await controller.dispose();
    } catch (_) {}
  }

  void _liberarVideoBanner() {
    _tokenVideoBanner++;
    final controller = _videoBannerController;
    _videoBannerController = null;
    _videoBannerUrl = null;
    _videoBannerListo = false;
    if (controller != null) {
      _disponerControladorVideoSeguro(controller);
    }
  }

  Future<void> _configurarVideoBanner() async {
    final url = _bannerConfig.videoUrl?.trim();
    final debeUsarVideo =
        _bannerConfig.debeMostrarse &&
        _bannerConfig.modo == ModoBannerCatalogo.video &&
        url != null &&
        url.isNotEmpty;

    if (!debeUsarVideo) {
      if (mounted) {
        setState(_liberarVideoBanner);
      } else {
        _liberarVideoBanner();
      }
      return;
    }

    if (url == _videoBannerUrl && _videoBannerController != null) {
      return;
    }

    _liberarVideoBanner();
    final tokenActual = _tokenVideoBanner;
    _videoBannerUrl = url;

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      _liberarVideoBanner();
      return;
    }

    VideoPlayerController? controller;
    try {
      controller =
          (widget.crearControladorVideo ?? VideoPlayerController.networkUrl)(
            uri,
          );
      _videoBannerController = controller;

      await controller.initialize();
      if (!mounted ||
          tokenActual != _tokenVideoBanner ||
          !identical(controller, _videoBannerController)) {
        await _disponerControladorVideoSeguro(controller);
        return;
      }

      await controller.setVolume(0.0);
      if (!mounted ||
          tokenActual != _tokenVideoBanner ||
          !identical(controller, _videoBannerController)) {
        await _disponerControladorVideoSeguro(controller);
        return;
      }

      await controller.setLooping(true);
      if (!mounted ||
          tokenActual != _tokenVideoBanner ||
          !identical(controller, _videoBannerController)) {
        await _disponerControladorVideoSeguro(controller);
        return;
      }

      await controller.play();
      if (!mounted ||
          tokenActual != _tokenVideoBanner ||
          !identical(controller, _videoBannerController)) {
        await _disponerControladorVideoSeguro(controller);
        return;
      }

      setState(() {
        _videoBannerListo = true;
      });
    } catch (_) {
      if (controller == null ||
          identical(controller, _videoBannerController)) {
        _liberarVideoBanner();
        if (mounted) {
          setState(() {});
        }
      } else {
        await _disponerControladorVideoSeguro(controller);
      }
    }
  }

  Future<void> _cargarBanner() async {
    try {
      final config = await (widget.cargarBanner ??
          BannerController.cargarConfiguracion)();
      if (!mounted) return;

      setState(() {
        _bannerConfig = config.debeMostrarse ? config : BannerConfig.inicial();
        _cargandoBanner = false;
      });
      _configurarCarrusel();
      _configurarVideoBanner();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bannerConfig = BannerConfig.inicial();
        _cargandoBanner = false;
      });
      _configurarCarrusel();
      _configurarVideoBanner();
    }
  }

  List<Producto> _calcularProductosFiltrados({String? consulta}) {
    return filtrarProductosCatalogo(
      _productos,
      consulta ?? _buscarCtrl.text,
      categoriaId: _categoriaSeleccionadaId,
    );
  }

  void _filtrarProductos(String consulta) {
    setState(() {
      _productosFiltrados = _calcularProductosFiltrados(consulta: consulta);
    });
  }

  void _seleccionarCategoria(String? categoriaId) {
    if (_categoriaSeleccionadaId == categoriaId) return;
    setState(() {
      _categoriaSeleccionadaId = categoriaId;
      _productosFiltrados = _calcularProductosFiltrados();
    });
  }

  int _calcularColumnas(double ancho) {
    if (ancho < 600) return 2; // Teléfonos móviles
    if (ancho < 900) return 3; // Tabletas / pantallas medianas
    return 4; // Escritorio (máximo 4 columnas)
  }

  double _calcularAltoTarjeta(double ancho) {
    final columnas = _calcularColumnas(ancho);
    final paddingHorizontal = ancho < 600 ? 16.0 : 24.0;
    final espaciado = ancho < 600 ? 12.0 : 18.0;
    final anchoEfectivo = ancho > 1280 ? 1280.0 : ancho;
    final anchoTarjeta =
        (anchoEfectivo - (paddingHorizontal * 2) - (espaciado * (columnas - 1))) /
        columnas;
    final altoImagen = anchoTarjeta * (4 / 3); // Proporción 3:4 a todo el ancho

    // Altura exacta = imagen 3:4 + bloque inferior (padding 24 + nombre 2 líneas ~36 + espacio 12 + botón 44)
    return altoImagen + 116;
  }

  ThemeData _construirTemaBoutique(BuildContext context) {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: _fondoPagina,
      colorScheme: ColorScheme.light(
        primary: _rojoMarca,
        onPrimary: _blanco,
        surface: _blanco,
        onSurface: _negroElegante,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: _negroElegante,
        displayColor: _negroElegante,
      ),
    );
  }

  void _agregarAlCarrito(Producto producto) {
    if (!mounted) return;

    final id = producto.id.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _negroElegante,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: _rosaClaro,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No se pudo agregar este producto porque no tiene un identificador válido.',
                  style: TextStyle(color: _blanco, fontSize: 13.5),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _productosCarrito[id] = producto;
      _cantidadesCarrito[id] = (_cantidadesCarrito[id] ?? 0) + 1;
    });

    final cantidadActual = _cantidadesCarrito[id]!;
    final mensaje = cantidadActual > 1
        ? '"${producto.nombre}" se agregó al carrito ($cantidadActual unidades).'
        : '"${producto.nombre}" se agregó al carrito.';

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _negroElegante,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: _rosaClaro,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: _blanco, fontSize: 13.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _cambiarCantidadCarrito(
    String id,
    int delta,
    StateSetter setModalState,
  ) {
    if (!mounted) return;
    final cantidadActual = _cantidadesCarrito[id] ?? 0;
    final nuevaCantidad = cantidadActual + delta;

    setState(() {
      if (nuevaCantidad <= 0) {
        _cantidadesCarrito.remove(id);
        _productosCarrito.remove(id);
      } else {
        _cantidadesCarrito[id] = nuevaCantidad;
      }
    });

    setModalState(() {});
  }

  String _construirMensajeWhatsApp() {
    final idsProductos = _productosCarrito.keys
        .where((id) => (_cantidadesCarrito[id] ?? 0) > 0)
        .toList();

    final buffer = StringBuffer();
    buffer.writeln(
      'Hola Accesorios Ayala, me gustaría solicitar información sobre estos productos:',
    );
    buffer.writeln();

    for (final id in idsProductos) {
      final producto = _productosCarrito[id]!;
      final cantidad = _cantidadesCarrito[id] ?? 0;
      final subtotal = producto.precio * cantidad;

      buffer.writeln('• ${producto.nombre}');
      buffer.writeln('  Cantidad: $cantidad');
      buffer.writeln(
        '  Precio unitario: L. ${producto.precio.toStringAsFixed(2)}',
      );
      buffer.writeln('  Subtotal: L. ${subtotal.toStringAsFixed(2)}');

      final urlFoto = producto.imageUrl?.trim();
      if (urlFoto != null && urlFoto.isNotEmpty) {
        final uriFoto = Uri.tryParse(urlFoto);
        final esUrlValida =
            uriFoto != null &&
            (uriFoto.scheme == 'http' || uriFoto.scheme == 'https') &&
            uriFoto.host.isNotEmpty;
        if (esUrlValida) {
          buffer.writeln('  Foto: $urlFoto');
        }
      }
      buffer.writeln();
    }

    buffer.writeln(
      'Total estimado: L. ${_totalPrecioCarrito.toStringAsFixed(2)}',
    );
    buffer.write('Precios y disponibilidad sujetos a confirmación.');

    return buffer.toString();
  }

  Future<void> _solicitarPorWhatsApp() async {
    if (_totalUnidadesCarrito <= 0) return;

    final mensaje = _construirMensajeWhatsApp();
    final url = Uri.https('wa.me', '/50499127141', {'text': mensaje});

    try {
      final abierto = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!abierto && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _negroElegante,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: const Text(
              'No se pudo abrir WhatsApp. Verifica que esté disponible en tu dispositivo.',
              style: TextStyle(color: _blanco, fontSize: 13.5),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _negroElegante,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Text(
            'Ocurrió un problema al intentar abrir WhatsApp. Intenta nuevamente.',
            style: TextStyle(color: _blanco, fontSize: 13.5),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _mostrarModalCarrito() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final altoPantalla = MediaQuery.of(modalContext).size.height;
            final idsProductos = _productosCarrito.keys
                .where((id) => (_cantidadesCarrito[id] ?? 0) > 0)
                .toList();
            final estaVacio = idsProductos.isEmpty;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 620,
                  maxHeight: altoPantalla * 0.88,
                ),
                child: Container(
                  margin: const EdgeInsets.only(top: 40),
                  decoration: const BoxDecoration(
                    color: _blanco,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Indicador superior del modal
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: _bordeSuave,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Encabezado del modal de carrito
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _rosaClaro,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _bordeSuave),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: _rojoMarca,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mi carrito',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: _negroElegante,
                                      ),
                                    ),
                                    Text(
                                      estaVacio
                                          ? 'Sin productos seleccionados'
                                          : '$_totalUnidadesCarrito ${_totalUnidadesCarrito == 1 ? 'unidad agregada' : 'unidades agregadas'}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: _grisTexto,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(modalContext),
                                icon: const Icon(Icons.close_rounded),
                                color: _grisTexto,
                                tooltip: 'Cerrar',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: _bordeSuave, height: 1),

                          if (estaVacio) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 36,
                                horizontal: 16,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: _rosaClaro,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: _bordeSuave),
                                      ),
                                      child: const Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 42,
                                        color: _rojoMarca,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Tu carrito está vacío',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _negroElegante,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Explora nuestra colección y agrega tus accesorios o detalles favoritos.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: _grisTexto,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: idsProductos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, index) {
                                  final id = idsProductos[index];
                                  final producto = _productosCarrito[id]!;
                                  final cantidad = _cantidadesCarrito[id] ?? 0;
                                  final subtotal = producto.precio * cantidad;

                                  return _construirItemCarrito(
                                    producto: producto,
                                    cantidad: cantidad,
                                    subtotal: subtotal,
                                    onDisminuir: () => _cambiarCantidadCarrito(
                                      id,
                                      -1,
                                      setModalState,
                                    ),
                                    onIncrementar: () => _cambiarCantidadCarrito(
                                      id,
                                      1,
                                      setModalState,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _rosaClaro,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _bordeSuave),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total del carrito',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: _negroElegante,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Precios en Lempiras (L.)',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: _grisTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'L. ${_totalPrecioCarrito.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: _rojoMarca,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _solicitarPorWhatsApp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _rojoMarca,
                                  foregroundColor: _blanco,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_rounded, size: 20),
                                label: const Text(
                                  'Solicitar por WhatsApp',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(modalContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _rojoMarca,
                                backgroundColor: _blanco,
                                side: const BorderSide(
                                  color: _rojoMarca,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.storefront_rounded,
                                size: 19,
                              ),
                              label: const Text(
                                'Seguir explorando',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _construirItemCarrito({
    required Producto producto,
    required int cantidad,
    required double subtotal,
    required VoidCallback onDisminuir,
    required VoidCallback onIncrementar,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fondoPagina,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: _construirVisualProducto(
                producto,
                iconoSize: 26,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _negroElegante,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Precio unitario: L. ${producto.precio.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _grisTexto,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _blanco,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _bordeSuave),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onDisminuir,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(9),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '−',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _rojoMarca,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: const BoxDecoration(
                              color: _rosaClaro,
                              border: Border.symmetric(
                                vertical: BorderSide(color: _bordeSuave),
                              ),
                            ),
                            child: Text(
                              '$cantidad',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _negroElegante,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onIncrementar,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(9),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: _rojoMarca,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Subtotal: L. ${subtotal.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _negroElegante,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBadgeDisponibleModal() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _doradoElegante.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _doradoElegante.withValues(alpha: 0.45)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: _doradoElegante,
            size: 13,
          ),
          SizedBox(width: 5),
          Text(
            'Disponible',
            style: TextStyle(
              color: _champan,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPrecioModal(Producto producto, {double fontSize = 26}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text(
          'L.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _doradoElegante,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          producto.precio.toStringAsFixed(2),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: _champan,
          ),
        ),
      ],
    );
  }

  Widget _construirBotonAgregarModal(
    BuildContext modalContext,
    Producto producto,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(modalContext);
          _agregarAlCarrito(producto);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _doradoElegante,
          foregroundColor: _negroPortada,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: const Text(
          'Agregar al carrito',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleProducto(BuildContext context, Producto producto) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (modalContext) {
        final tamanoPantalla = MediaQuery.sizeOf(modalContext);
        final esEscritorio = tamanoPantalla.width >= 760;
        final maxAltura = tamanoPantalla.height * 0.85;
        final altoEscritorio = maxAltura < 520.0 ? maxAltura : 520.0;
        final altoImagenMovil = (tamanoPantalla.height * 0.28).clamp(
          150.0,
          230.0,
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: esEscritorio ? 32 : 16,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: esEscritorio ? 850 : 480,
              maxHeight: maxAltura,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _negroPortada,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _doradoElegante.withValues(alpha: 0.30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: esEscritorio
                    ? SizedBox(
                        height: altoEscritorio,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 11,
                              child: Container(
                                color: _negroSuperficie,
                                padding: const EdgeInsets.all(14),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: _construirVisualProducto(
                                    producto,
                                    iconoSize: 72,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: _doradoElegante.withValues(alpha: 0.16),
                            ),
                            Expanded(
                              flex: 12,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  18,
                                  20,
                                  22,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _construirBadgeDisponibleModal(),
                                        IconButton(
                                          onPressed: () =>
                                              Navigator.pop(modalContext),
                                          icon: const Icon(Icons.close_rounded),
                                          color: _champan,
                                          tooltip: 'Cerrar',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      producto.nombre,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                        color: _blanco,
                                        height: 1.22,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _construirPrecioModal(producto),
                                    const SizedBox(height: 14),
                                    Divider(
                                      color: _doradoElegante.withValues(
                                        alpha: 0.18,
                                      ),
                                      height: 1,
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Descripción del producto',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: _doradoElegante,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Text(
                                          producto.descripcion,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _champan.withValues(
                                              alpha: 0.88,
                                            ),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _construirBotonAgregarModal(
                                      modalContext,
                                      producto,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: altoImagenMovil,
                                color: _negroSuperficie,
                                padding: const EdgeInsets.all(10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: _construirVisualProducto(
                                    producto,
                                    iconoSize: 64,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: _negroPortada.withValues(alpha: 0.78),
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    onPressed: () =>
                                        Navigator.pop(modalContext),
                                    icon: const Icon(Icons.close_rounded),
                                    color: _champan,
                                    tooltip: 'Cerrar',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                14,
                                18,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _construirBadgeDisponibleModal(),
                                  const SizedBox(height: 8),
                                  Text(
                                    producto.nombre,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: _blanco,
                                      height: 1.22,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _construirPrecioModal(producto, fontSize: 23),
                                  const SizedBox(height: 12),
                                  Divider(
                                    color: _doradoElegante.withValues(
                                      alpha: 0.18,
                                    ),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Descripción del producto',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: _doradoElegante,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    producto.descripcion,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _champan.withValues(alpha: 0.88),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                            child: _construirBotonAgregarModal(
                              modalContext,
                              producto,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _construirTemaBoutique(context),
      child: Scaffold(
        backgroundColor: _negroPortada,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ancho = constraints.maxWidth;
              final esEscritorio = ancho >= 800;
              final columnas = _calcularColumnas(ancho);
              final altoTarjeta = _calcularAltoTarjeta(ancho);
              final paddingHorizontal = ancho < 600 ? 16.0 : 24.0;
              final paddingContenido = ancho > 1280
                  ? (ancho - 1280) / 2 + paddingHorizontal
                  : paddingHorizontal;

              return Column(
                children: [
                  // 1. Encabezado fijo premium en negro profundo + Buscador + Carrito
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _negroPortada,
                      border: Border(
                        bottom: BorderSide(
                          color: _doradoElegante.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: paddingHorizontal,
                            vertical: esEscritorio ? 14 : 12,
                          ),
                          child: _construirEncabezado(
                            context,
                            esEscritorio: esEscritorio,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollCtrl,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // 2. Hero Banner premium de ancho completo en negro y dorado
                        SliverToBoxAdapter(
                          child: _construirBannerBienvenida(
                            esEscritorio: esEscritorio,
                            paddingHorizontal: paddingHorizontal,
                          ),
                        ),

                        // 3. Barra de título de sección y conteo de resultados
                        SliverToBoxAdapter(
                          child: Padding(
                            key: _claveSeccionProductos,
                            padding: EdgeInsets.fromLTRB(
                              paddingContenido,
                              20,
                              paddingContenido,
                              12,
                            ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome_rounded,
                                          color: _doradoElegante,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Nuestra Colección',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: esEscritorio ? 22 : 19,
                                              fontWeight: FontWeight.w800,
                                              color: _blanco,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_cargando && _errorCarga == null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _negroSuperficie,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _doradoElegante
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        '${_productosFiltrados.length} ${_productosFiltrados.length == 1 ? 'creación' : 'creaciones'}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: _champan,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                        // 3.5. Barra responsive de filtros por categoría
                        if (!_cargando &&
                            _errorCarga == null &&
                            _hayProductosVisibles)
                          SliverToBoxAdapter(
                            child: _construirBarraCategorias(
                              paddingContenido: paddingContenido,
                              ancho: ancho,
                            ),
                          ),

                          // 4. Estados visuales: Cargando, Error, Sin productos registrados, Sin coincidencias o Cuadrícula
                          if (_cargando)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 56,
                                ),
                                child: _construirEstadoCargando(),
                              ),
                            )
                          else if (_errorCarga != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 48,
                                ),
                                child: _construirEstadoError(),
                              ),
                            )
                          else if (!_hayProductosVisibles)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 48,
                                ),
                                child: _construirEstadoCatalogoVacio(),
                              ),
                            )
                          else if (_productosFiltrados.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 48,
                                ),
                                child: _construirEstadoBusquedaSinResultados(),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                paddingContenido,
                                4,
                                paddingContenido,
                                36,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columnas,
                                  mainAxisSpacing: ancho < 600 ? 12 : 18,
                                  crossAxisSpacing: ancho < 600 ? 12 : 18,
                                  mainAxisExtent: altoTarjeta,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final producto = _productosFiltrados[index];
                                    return _construirTarjetaProducto(
                                      context,
                                      producto,
                                    );
                                  },
                                  childCount: _productosFiltrados.length,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _construirEncabezado(
    BuildContext context, {
    required bool esEscritorio,
  }) {
    return Column(
      children: [
        Row(
          children: [
            // Logo oficial con marco oscuro y acento dorado
            Container(
              width: esEscritorio ? 50 : 44,
              height: esEscritorio ? 50 : 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _negroSuperficie,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _doradoElegante.withValues(alpha: 0.40),
                ),
              ),
              child: Image.asset(
                'assets/logo/logo_ayala.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_awesome_rounded,
                  color: _doradoElegante,
                ),
              ),
            ),
            SizedBox(width: esEscritorio ? 14 : 10),

            // Marca y subtítulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accesorios Ayala',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: esEscritorio ? 20 : 18,
                      fontWeight: FontWeight.w800,
                      color: _blanco,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (esEscritorio) ...[
                    const SizedBox(height: 2),
                    _construirEslogan(esEscritorio: true),
                  ],
                ],
              ),
            ),

            // En escritorio, el buscador se integra en la misma fila superior
            if (esEscritorio) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: 340,
                child: _construirCampoBusqueda(),
              ),
              const SizedBox(width: 16),
            ],

            // Indicador visual de carrito
            _construirIndicadorCotizacion(context),
          ],
        ),

        // En móvil, el subtítulo y el buscador ocupan todo el ancho debajo
        if (!esEscritorio) ...[
          const SizedBox(height: 8),
          _construirEslogan(esEscritorio: false),
          const SizedBox(height: 10),
          _construirCampoBusqueda(),
        ],
      ],
    );
  }

  Widget _construirEslogan({required bool esEscritorio}) {
    return Row(
      crossAxisAlignment:
          esEscritorio ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: esEscritorio ? 0 : 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _doradoElegante,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'Accesorios, grabados láser y regalos personalizados',
            maxLines: esEscritorio ? 1 : 2,
            overflow:
                esEscritorio ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _champan.withValues(alpha: 0.88),
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirCampoBusqueda() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _buscarCtrl,
        onChanged: _filtrarProductos,
        style: const TextStyle(
          fontSize: 14,
          color: _blanco,
        ),
        cursorColor: _doradoElegante,
        decoration: InputDecoration(
          hintText: 'Buscar pulseras, collares, grabados, regalos...',
          hintStyle: TextStyle(
            color: _champan.withValues(alpha: 0.58),
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _doradoElegante,
            size: 20,
          ),
          suffixIcon: _buscarCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.cancel_rounded,
                    color: _champan.withValues(alpha: 0.75),
                    size: 19,
                  ),
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () {
                    _buscarCtrl.clear();
                    _filtrarProductos('');
                  },
                )
              : null,
          filled: true,
          fillColor: _negroSuperficie,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _doradoElegante.withValues(alpha: 0.28),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: _doradoElegante,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirIndicadorCotizacion(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _mostrarModalCarrito,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _negroSuperficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _doradoElegante.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: _doradoElegante,
                    size: 21,
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _doradoElegante,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_totalUnidadesCarrito',
                        style: const TextStyle(
                          color: _negroPortada,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const Text(
                'Mi carrito',
                style: TextStyle(
                  color: _blanco,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirMediaBanner(Widget imagenRespaldo) {
    if (!_bannerConfig.debeMostrarse) {
      return imagenRespaldo;
    }

    if (_bannerConfig.modo == ModoBannerCatalogo.imagen) {
      final urlImagen = _bannerConfig.imagenUrl?.trim();
      if (urlImagen == null || urlImagen.isEmpty) {
        return imagenRespaldo;
      }

      return Image.network(
        urlImagen,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return imagenRespaldo;
        },
        errorBuilder: (_, __, ___) => imagenRespaldo,
      );
    }

    if (_bannerConfig.modo == ModoBannerCatalogo.carrusel) {
      final items = _itemsCarruselActivos;
      if (items.isEmpty) {
        return imagenRespaldo;
      }

      return PageView.builder(
        controller: _carruselPageCtrl,
        itemCount: items.length,
        onPageChanged: (indice) {
          _indiceCarruselActual = indice;
        },
        itemBuilder: (context, index) {
          return Image.network(
            items[index].url,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return imagenRespaldo;
            },
            errorBuilder: (_, __, ___) => imagenRespaldo,
          );
        },
      );
    }

    if (_bannerConfig.modo == ModoBannerCatalogo.video) {
      final controller = _videoBannerController;
      if (!_videoBannerListo ||
          controller == null ||
          !controller.value.isInitialized ||
          controller.value.hasError) {
        return imagenRespaldo;
      }

      final tamano = controller.value.size;
      final ancho = tamano.width > 0 ? tamano.width : 16.0;
      final alto = tamano.height > 0 ? tamano.height : 9.0;
      final vistaVideo =
          widget.construirVistaVideo?.call(controller) ??
          VideoPlayer(controller);

      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: ancho,
            height: alto,
            child: vistaVideo,
          ),
        ),
      );
    }

    return imagenRespaldo;
  }

  Widget _construirBannerBienvenida({
    required bool esEscritorio,
    required double paddingHorizontal,
  }) {
    final imagenRespaldo = Image.asset(
      'assets/images/banner_pulsera_premium.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => Container(color: _negroPortada),
    );
    final imagenHero = _construirMediaBanner(imagenRespaldo);

    if (esEscritorio) {
      return Container(
        width: double.infinity,
        color: _negroPortada,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: SizedBox(
              height: 440,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        paddingHorizontal,
                        36,
                        24,
                        36,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCESORIOS AYALA · COLECCIÓN',
                            style: TextStyle(
                              color: _doradoElegante,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Detalles que cuentan tu historia.',
                            style: TextStyle(
                              color: _blanco,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Piezas especiales para personas y momentos inolvidables.',
                            style: TextStyle(
                              color: _champan,
                              fontSize: 16,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ElevatedButton(
                            onPressed: _irAProductos,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _doradoElegante,
                              foregroundColor: _negroPortada,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'EXPLORAR COLECCIONES',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        imagenHero,
                        // Degradado lateral para fundir la fotografía con el fondo #0B0B0B
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                _negroPortada,
                                Color(0x990B0B0B),
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.22, 0.55],
                            ),
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _negroPortada,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.18],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Composición móvil: fotografía protagonista arriba y texto debajo sobre #0B0B0B
    return Container(
      width: double.infinity,
      color: _negroPortada,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imagenHero,
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        _negroPortada,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.35],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              paddingHorizontal,
              8,
              paddingHorizontal,
              28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACCESORIOS AYALA · COLECCIÓN',
                  style: TextStyle(
                    color: _doradoElegante,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Detalles que cuentan tu historia.',
                  style: TextStyle(
                    color: _blanco,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Piezas especiales para personas y momentos inolvidables.',
                  style: TextStyle(
                    color: _champan,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _irAProductos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _doradoElegante,
                      foregroundColor: _negroPortada,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'EXPLORAR COLECCIONES',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaProducto(BuildContext context, Producto producto) {
    return _TarjetaProductoPremium(
      producto: producto,
      visual: _construirVisualProducto(
        producto,
        iconoSize: 48,
        fit: BoxFit.cover,
      ),
      onTapDetalle: () => _mostrarDetalleProducto(context, producto),
      onAgregarCarrito: () => _agregarAlCarrito(producto),
    );
  }

  Widget _construirVisualProducto(
    Producto producto, {
    required double iconoSize,
    BoxFit fit = BoxFit.cover,
  }) {
    final tieneUrl =
        producto.imageUrl != null && producto.imageUrl!.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_negroSuperficie, Color(0xFF1C1C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: tieneUrl
          ? Image.network(
              producto.imageUrl!.trim(),
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _doradoElegante,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _construirPlaceholderNeutro(
                iconoSize,
              ),
            )
          : _construirPlaceholderNeutro(iconoSize),
    );
  }

  Widget _construirPlaceholderNeutro(double iconoSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: iconoSize * 1.65,
          height: iconoSize * 1.65,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            shape: BoxShape.circle,
            border: Border.all(
              color: _doradoElegante.withValues(alpha: 0.30),
            ),
          ),
        ),
        Icon(
          Icons.card_giftcard_rounded,
          size: iconoSize,
          color: _doradoElegante.withValues(alpha: 0.80),
        ),
      ],
    );
  }

  Widget _construirContenedorEstadoOscuro({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: _negroSuperficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _doradoElegante.withValues(alpha: 0.25),
        ),
      ),
      child: child,
    );
  }

  Widget _construirEstadoCargando() {
    return _construirContenedorEstadoOscuro(
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _doradoElegante,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando catálogo...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _blanco,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoError() {
    return _construirContenedorEstadoOscuro(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _doradoElegante.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 38,
              color: _doradoElegante,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _errorCarga ?? 'Ocurrió un problema al cargar el catálogo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _blanco,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verifica tu conexión a internet e inténtalo nuevamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: _champan.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _cargarProductos,
            style: ElevatedButton.styleFrom(
              backgroundColor: _doradoElegante,
              foregroundColor: _negroPortada,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Reintentar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoCatalogoVacio() {
    return _construirContenedorEstadoOscuro(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _doradoElegante.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              size: 38,
              color: _doradoElegante,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no hay productos disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _blanco,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Muy pronto actualizaremos nuestro catálogo con nuevas creaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: _champan.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBarraCategorias({
    required double paddingContenido,
    required double ancho,
  }) {
    final chips = <Widget>[
      _construirChipCategoria(
        etiqueta: 'Todos',
        seleccionado: _categoriaSeleccionadaId == null,
        onTap: () => _seleccionarCategoria(null),
      ),
      for (final categoria in _categorias)
        _construirChipCategoria(
          etiqueta: categoria.nombre,
          seleccionado: _categoriaSeleccionadaId == categoria.id,
          onTap: () => _seleccionarCategoria(categoria.id),
        ),
    ];

    final esPantallaAmplia = ancho >= 768;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esPantallaAmplia)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: paddingContenido),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: paddingContenido),
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    chips[i],
                  ],
                ],
              ),
            ),
          if (_errorCategorias != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                paddingContenido,
                8,
                paddingContenido,
                0,
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'No se pudieron cargar las categorías.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _champan.withValues(alpha: 0.78),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _cargandoCategorias ? null : _cargarCategorias,
                    style: TextButton.styleFrom(
                      foregroundColor: _doradoElegante,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text(
                      'Reintentar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirChipCategoria({
    required String etiqueta,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return Material(
      color: seleccionado ? _doradoElegante : _negroSuperficie,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: seleccionado
                  ? _doradoElegante
                  : _doradoElegante.withValues(alpha: 0.30),
            ),
          ),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: 13,
              fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
              color: seleccionado ? _negroPortada : _champan,
              letterSpacing: 0.15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirEstadoBusquedaSinResultados() {
    final tieneCategoria = _categoriaSeleccionadaId != null;
    final tieneBusqueda = _buscarCtrl.text.trim().isNotEmpty;

    final String titulo;
    final String subtitulo;
    if (tieneCategoria && tieneBusqueda) {
      titulo = 'No encontramos productos que coincidan en esta categoría';
      subtitulo =
          'Prueba con otra palabra clave, limpia el buscador o regresa a "Todos".';
    } else if (tieneCategoria) {
      titulo = 'No hay productos en esta categoría';
      subtitulo =
          'Prueba seleccionando otra categoría o regresa a "Todos" para ver toda la colección.';
    } else {
      titulo = 'No encontramos productos que coincidan';
      subtitulo =
          'Prueba buscando con otra palabra clave o limpia el buscador para ver toda la colección.';
    }

    return _construirContenedorEstadoOscuro(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _doradoElegante.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              tieneCategoria && !tieneBusqueda
                  ? Icons.category_outlined
                  : Icons.search_off_rounded,
              size: 38,
              color: _doradoElegante,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _blanco,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: _champan.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (tieneBusqueda)
                OutlinedButton.icon(
                  onPressed: () {
                    _buscarCtrl.clear();
                    _filtrarProductos('');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _doradoElegante,
                    side: BorderSide(
                      color: _doradoElegante.withValues(alpha: 0.55),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    tieneCategoria
                        ? 'Limpiar búsqueda'
                        : 'Mostrar todos los productos',
                  ),
                ),
              if (tieneCategoria)
                ElevatedButton.icon(
                  onPressed: () {
                    if (tieneBusqueda) _buscarCtrl.clear();
                    _seleccionarCategoria(null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _doradoElegante,
                    foregroundColor: _negroPortada,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.apps_rounded, size: 18),
                  label: const Text(
                    'Volver a Todos',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaProductoPremium extends StatefulWidget {
  final Producto producto;
  final Widget visual;
  final VoidCallback onTapDetalle;
  final VoidCallback onAgregarCarrito;

  const _TarjetaProductoPremium({
    required this.producto,
    required this.visual,
    required this.onTapDetalle,
    required this.onAgregarCarrito,
  });

  @override
  State<_TarjetaProductoPremium> createState() =>
      _TarjetaProductoPremiumState();
}

class _TarjetaProductoPremiumState extends State<_TarjetaProductoPremium> {
  static const Color _tarjetaOscura = Color(0xFF171717);
  static const Color _superficieSecundaria = Color(0xFF141414);
  static const Color _doradoElegante = Color(0xFFC5A46D);
  static const Color _champan = Color(0xFFF2E5C9);

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _tarjetaOscura,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _doradoElegante.withValues(alpha: _hover ? 0.58 : 0.22),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hover
                  ? _doradoElegante.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.35),
              blurRadius: _hover ? 20 : 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTapDetalle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.visual,
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  color: _doradoElegante.withValues(alpha: 0.14),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.producto.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.25,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'L. ',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _champan,
                                      ),
                                    ),
                                    TextSpan(
                                      text: widget.producto.precio
                                          .toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _doradoElegante,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Agregar al carrito',
                              child: Material(
                                color: _superficieSecundaria,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: widget.onAgregarCarrito,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _doradoElegante.withValues(
                                          alpha: _hover ? 0.70 : 0.45,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 20,
                                      color: _doradoElegante,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
