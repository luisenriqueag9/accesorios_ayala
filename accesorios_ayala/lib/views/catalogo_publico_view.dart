import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/producto_controller.dart';
import '../models/producto.dart';
import '../utils/widgets/glass_container.dart';

class CatalogoPublicoView extends StatefulWidget {
  const CatalogoPublicoView({super.key});

  @override
  State<CatalogoPublicoView> createState() => _CatalogoPublicoViewState();
}

class _CatalogoPublicoViewState extends State<CatalogoPublicoView> {
  // Paleta de identidad visual — Boutique Accesorios Ayala
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rojoSuave = Color(0xFFB81B24);
  static const Color _blanco = Color(0xFFFFFFFF);
  static const Color _rosaClaro = Color(0xFFFFF1F1);
  static const Color _fondoPagina = Color(0xFFFFFAFA);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF2E1E2);

  final TextEditingController _buscarCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _claveSeccionProductos = GlobalKey();

  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  bool _cargando = true;
  String? _errorCarga;

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
  }

  @override
  void dispose() {
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
      final lista = await ProductoController.cargarProductos();
      if (!mounted) return;

      final texto = _buscarCtrl.text.trim().toLowerCase();
      setState(() {
        _productos = lista;
        if (texto.isEmpty) {
          _productosFiltrados = List<Producto>.from(_productos);
        } else {
          _productosFiltrados = _productos.where((p) {
            return p.nombre.toLowerCase().contains(texto) ||
                p.descripcion.toLowerCase().contains(texto);
          }).toList();
        }
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

  void _filtrarProductos(String consulta) {
    final texto = consulta.trim().toLowerCase();
    setState(() {
      if (texto.isEmpty) {
        _productosFiltrados = List<Producto>.from(_productos);
      } else {
        _productosFiltrados = _productos.where((p) {
          return p.nombre.toLowerCase().contains(texto) ||
              p.descripcion.toLowerCase().contains(texto);
        }).toList();
      }
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

  void _mostrarDetalleProducto(BuildContext context, Producto producto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              margin: const EdgeInsets.only(top: 40),
              decoration: const BoxDecoration(
                color: _blanco,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
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
                      const SizedBox(height: 8),

                      // Botón de cierre del modal
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded),
                          color: _grisTexto,
                          tooltip: 'Cerrar',
                        ),
                      ),

                      // Imagen / Placeholder grande formato escaparate (completa sin recortes)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 220,
                            maxHeight: 360,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: _construirVisualProducto(
                              producto,
                              iconoSize: 78,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Nombre y Precio
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: _negroElegante,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            'L.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _rojoMarca,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            producto.precio.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: _negroElegante,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _rosaClaro,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _bordeSuave),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  color: _rojoMarca,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Disponible',
                                  style: TextStyle(
                                    color: _rojoMarca,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: _bordeSuave, height: 1),
                      const SizedBox(height: 16),

                      const Text(
                        'Descripción del producto',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _negroElegante,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        producto.descripcion,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: _grisTexto,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón para agregar el producto al carrito
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(modalContext);
                            _agregarAlCarrito(producto);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _rojoMarca,
                            foregroundColor: _blanco,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text(
                            'Agregar al carrito',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _construirTemaBoutique(context),
      child: Scaffold(
        backgroundColor: _fondoPagina,
        body: Stack(
          children: [
            // Halo decorativo superior en rosa muy claro y blanco
            Positioned(
              top: -100,
              left: -60,
              right: -60,
              height: 320,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _rosaClaro,
                      Color(0xFFFFF7F7),
                      _fondoPagina,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ancho = constraints.maxWidth;
                  final esEscritorio = ancho >= 800;
                  final columnas = _calcularColumnas(ancho);
                  final altoTarjeta = _calcularAltoTarjeta(ancho);
                  final paddingHorizontal = ancho < 600 ? 16.0 : 24.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        children: [
                          // 1. Encabezado fijo elegante + Buscador
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              paddingHorizontal,
                              12,
                              paddingHorizontal,
                              8,
                            ),
                            child: _construirEncabezado(
                              context,
                              esEscritorio: esEscritorio,
                            ),
                          ),
                          Expanded(
                            child: CustomScrollView(
                              controller: _scrollCtrl,
                              physics: const BouncingScrollPhysics(),
                              slivers: [
                                // 2. Hero Banner moderno
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: paddingHorizontal,
                                      vertical: 8,
                                    ),
                                    child: _construirBannerBienvenida(
                                      esEscritorio: esEscritorio,
                                    ),
                                  ),
                                ),

                          // 3. Barra de título de sección y conteo de resultados
                          SliverToBoxAdapter(
                            child: Padding(
                              key: _claveSeccionProductos,
                              padding: EdgeInsets.fromLTRB(
                                paddingHorizontal,
                                12,
                                paddingHorizontal,
                                12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        color: _rojoMarca,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Nuestra Colección',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: _negroElegante,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!_cargando && _errorCarga == null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _rosaClaro,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _bordeSuave,
                                        ),
                                      ),
                                      child: Text(
                                        '${_productosFiltrados.length} ${_productosFiltrados.length == 1 ? 'creación' : 'creaciones'}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: _rojoMarca,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
                          else if (_productos.isEmpty)
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
                                paddingHorizontal,
                                4,
                                paddingHorizontal,
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirEncabezado(
    BuildContext context, {
    required bool esEscritorio,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 22 : 14,
        vertical: esEscritorio ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: _blanco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bordeSuave),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Logo oficial con marco blanco limpio
              Container(
                width: esEscritorio ? 52 : 46,
                height: esEscritorio ? 52 : 46,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _blanco,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _bordeSuave),
                ),
                child: Image.asset(
                  'assets/logo/logo_ayala.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.auto_awesome_rounded,
                    color: _negroElegante,
                  ),
                ),
              ),
              SizedBox(width: esEscritorio ? 14 : 10),

              // Marca y línea de negocio
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
                        color: _negroElegante,
                        letterSpacing: 0.2,
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
      ),
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
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFD98496),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Accesorios, grabados láser y regalos personalizados',
            maxLines: esEscritorio ? 1 : 2,
            overflow:
                esEscritorio ? TextOverflow.ellipsis : TextOverflow.visible,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _grisTexto,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirCampoBusqueda() {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _buscarCtrl,
        onChanged: _filtrarProductos,
        style: const TextStyle(
          fontSize: 14.5,
          color: _negroElegante,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar pulseras, collares, regalos, detalles...',
          hintStyle: const TextStyle(
            color: _grisTexto,
            fontSize: 13.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _rojoMarca,
            size: 22,
          ),
          suffixIcon: _buscarCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: _grisTexto,
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
          fillColor: _blanco,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bordeSuave),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: _rojoMarca,
              width: 1.6,
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_rojoMarca, _rojoSuave],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _rojoMarca.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    color: _blanco,
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
                        color: _blanco,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_totalUnidadesCarrito',
                        style: const TextStyle(
                          color: _rojoMarca,
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

  Widget _construirBannerBienvenida({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFEFF3),
            Color(0xFFFFF7F9),
            _blanco,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3D7DF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Acentos geométricos sutiles en rosa suave
          Positioned(
            right: -28,
            top: -28,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFE8A4B3).withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 54,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE8A4B3).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(esEscritorio ? 30 : 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCE7EC),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFFF3D0D9),
                          ),
                        ),
                        child: const Text(
                          'ACCESORIOS · GRABADOS LÁSER · REGALOS',
                          style: TextStyle(
                            color: _negroElegante,
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Detalles que hacen la diferencia',
                        style: TextStyle(
                          color: _negroElegante,
                          fontSize: esEscritorio ? 30 : 22,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Accesorios, grabados láser y regalos personalizados para cada ocasión',
                        style: TextStyle(
                          color: _grisTexto,
                          fontSize: esEscritorio ? 15 : 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _irAProductos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _negroElegante,
                          foregroundColor: _blanco,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: esEscritorio ? 22 : 18,
                            vertical: esEscritorio ? 14 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                        label: const Text(
                          'Explorar productos',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (esEscritorio) ...[
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _blanco,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF3D7DF)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: _negroElegante,
                          size: 26,
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hecho a tu medida',
                              style: TextStyle(
                                color: _negroElegante,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Precios en Lempiras (L.)',
                              style: TextStyle(
                                color: _grisTexto,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaProducto(BuildContext context, Producto producto) {
    return Container(
      decoration: BoxDecoration(
        color: _blanco,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _bordeSuave.withValues(alpha: 0.75),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _negroElegante.withValues(alpha: 0.04),
            blurRadius: 16,
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
          onTap: () => _mostrarDetalleProducto(context, producto),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fotografía protagonista en proporción 3:4 con esquinas superiores redondeadas
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: _construirVisualProducto(
                      producto,
                      iconoSize: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              // Bloque inferior editorial: nombre, precio y botón circular discreto
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _negroElegante,
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
                                      color: _rojoMarca,
                                    ),
                                  ),
                                  TextSpan(
                                    text: producto.precio.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _negroElegante,
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
                              color: _rosaClaro,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _agregarAlCarrito(producto),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _bordeSuave,
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 20,
                                    color: _rojoMarca,
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
          colors: [_rosaClaro, Color(0xFFFFF8F8)],
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
                      color: _rojoMarca,
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
            color: _blanco.withValues(alpha: 0.70),
            shape: BoxShape.circle,
          ),
        ),
        Icon(
          Icons.card_giftcard_rounded,
          size: iconoSize,
          color: _rojoMarca.withValues(alpha: 0.75),
        ),
      ],
    );
  }

  Widget _construirEstadoCargando() {
    return GlassContainer(
      blur: 10,
      opacity: 0.85,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _rojoMarca,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Cargando catálogo...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _negroElegante,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoError() {
    return GlassContainer(
      blur: 10,
      opacity: 0.85,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _rojoMarca.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 38,
              color: _rojoMarca,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _errorCarga ?? 'Ocurrió un problema al cargar el catálogo.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verifica tu conexión a internet e inténtalo nuevamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: _grisTexto,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _cargarProductos,
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: _blanco,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoCatalogoVacio() {
    return GlassContainer(
      blur: 10,
      opacity: 0.85,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _rojoMarca.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              size: 38,
              color: _rojoMarca,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no hay productos disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Muy pronto actualizaremos nuestro catálogo con nuevas creaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: _grisTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoBusquedaSinResultados() {
    return GlassContainer(
      blur: 10,
      opacity: 0.85,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _rojoMarca.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 38,
              color: _rojoMarca,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No encontramos productos que coincidan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prueba buscando con otra palabra clave o limpia el buscador para ver toda la colección.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: _grisTexto,
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () {
              _buscarCtrl.clear();
              _filtrarProductos('');
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Mostrar todos los productos'),
          ),
        ],
      ),
    );
  }
}
