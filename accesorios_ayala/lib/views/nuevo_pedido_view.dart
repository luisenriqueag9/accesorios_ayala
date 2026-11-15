import 'package:flutter/material.dart';

import '../controllers/cliente_controller.dart';
import '../controllers/pedido_controller.dart';
import '../controllers/producto_controller.dart';
import '../models/cliente.dart';
import '../models/pedido.dart';
import '../models/producto.dart';

class NuevoPedidoView extends StatefulWidget {
  final List<Cliente> clientes;
  final List<Producto>? productos;
  @visibleForTesting
  final ValueChanged<List<PedidoItem>>? onItemsCambiados;
  @visibleForTesting
  final Future<Pedido> Function(Pedido borrador)? onRegistrarPedido;
  final ValueChanged<Pedido>? onPedidoRegistrado;

  const NuevoPedidoView({
    super.key,
    this.clientes = const [],
    this.productos,
    this.onItemsCambiados,
    this.onRegistrarPedido,
    this.onPedidoRegistrado,
  });

  @override
  State<NuevoPedidoView> createState() => _NuevoPedidoViewState();
}

class _NuevoPedidoViewState extends State<NuevoPedidoView> {
  static const double _breakpointEscritorio = 760;
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  final TextEditingController _buscarCtrl = TextEditingController();
  final TextEditingController _buscarProductoCtrl = TextEditingController();

  List<Cliente> _clientes = [];
  bool _cargandoClientes = false;
  bool _errorClientes = false;
  bool _mostrarResultados = false;
  Cliente? _clienteSeleccionado;

  List<Producto> _productos = [];
  bool _cargandoProductos = false;
  bool _errorProductos = false;
  bool _mostrarResultadosProductos = false;
  final List<PedidoItem> _itemsSeleccionados = [];
  final Map<String, TextEditingController> _personalizacionCtrls = {};
  final TextEditingController _costoEnvioCtrl = TextEditingController(
    text: '120.00',
  );
  final TextEditingController _descuentoCtrl = TextEditingController(
    text: '20',
  );
  int _siguienteSecuenciaItem = 1;
  String? _avisoProducto;
  DateTime? _fechaPrevistaEntrega;
  double? _costoEnvioValido = 120.0;
  String? _errorCostoEnvio;
  bool _descuentoMayoristaActivo = false;
  double? _descuentoPorcentajeValido = 20.0;
  String? _errorDescuento;
  bool _guardandoPedido = false;
  Pedido? _pedidoRegistrado;
  String? _mensajeErrorRegistro;
  String? _mensajeExitoRegistro;

  bool get _yaRegistrado => _pedidoRegistrado != null;

  double get _subtotalGeneral =>
      _itemsSeleccionados.fold(0.0, (total, item) => total + item.subtotal);

  @override
  void initState() {
    super.initState();
    if (widget.clientes.isNotEmpty) {
      _clientes = List<Cliente>.from(widget.clientes);
    } else {
      _cargarClientes(desdeInitState: true);
    }

    if (widget.productos != null) {
      _productos = List<Producto>.from(widget.productos!);
    } else {
      _cargarProductos(desdeInitState: true);
    }
  }

  @override
  void didUpdateWidget(covariant NuevoPedidoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientes.isNotEmpty) {
      _clientes = List<Cliente>.from(widget.clientes);
      _cargandoClientes = false;
      _errorClientes = false;
      _validarSeleccionActual();
    } else if (oldWidget.clientes.isNotEmpty && widget.clientes.isEmpty) {
      _cargarClientes();
    }

    if (widget.productos != null) {
      _productos = List<Producto>.from(widget.productos!);
      _cargandoProductos = false;
      _errorProductos = false;
      _validarProductosSeleccionados();
    } else if (oldWidget.productos != null && widget.productos == null) {
      _cargarProductos();
    }
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    _buscarProductoCtrl.dispose();
    _costoEnvioCtrl.dispose();
    _descuentoCtrl.dispose();
    for (final ctrl in _personalizacionCtrls.values) {
      ctrl.dispose();
    }
    _personalizacionCtrls.clear();
    super.dispose();
  }

  void _validarSeleccionActual() {
    if (_clienteSeleccionado != null &&
        !_clientes.any((c) => c.id == _clienteSeleccionado!.id)) {
      _clienteSeleccionado = null;
    }
  }

  void _validarProductosSeleccionados() {
    final idsDisponibles = _productos.map((p) => p.id).toSet();
    _itemsSeleccionados.removeWhere(
      (item) => !idsDisponibles.contains(item.productoId),
    );
  }

  Future<void> _cargarClientes({bool desdeInitState = false}) async {
    if (_cargandoClientes) return;

    if (desdeInitState) {
      _cargandoClientes = true;
      _errorClientes = false;
    } else {
      setState(() {
        _cargandoClientes = true;
        _errorClientes = false;
      });
    }

    try {
      final cargados = await ClienteController.cargarClientes();
      if (!mounted) return;

      setState(() {
        _clientes = cargados;
        _cargandoClientes = false;
        _errorClientes = false;
        _validarSeleccionActual();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargandoClientes = false;
        _errorClientes = true;
      });
    }
  }

  Future<void> _cargarProductos({bool desdeInitState = false}) async {
    if (_cargandoProductos) return;

    if (desdeInitState) {
      _cargandoProductos = true;
      _errorProductos = false;
    } else {
      setState(() {
        _cargandoProductos = true;
        _errorProductos = false;
      });
    }

    try {
      final cargados = await ProductoController.cargarProductos();
      if (!mounted) return;

      setState(() {
        _productos = cargados;
        _cargandoProductos = false;
        _errorProductos = false;
        _validarProductosSeleccionados();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargandoProductos = false;
        _errorProductos = true;
      });
    }
  }

  String _normalizarTexto(String texto) {
    const mapaTildes = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };

    final minusculas = texto.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final codeUnit in minusculas.runes) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(mapaTildes[char] ?? char);
    }
    return buffer.toString();
  }

  List<Cliente> _filtrarClientes() {
    final consulta = _normalizarTexto(_buscarCtrl.text);
    if (consulta.isEmpty) return _clientes;

    return _clientes
        .where((cliente) => _normalizarTexto(cliente.nombre).contains(consulta))
        .toList();
  }

  List<Producto> _filtrarProductos() {
    final consulta = _normalizarTexto(_buscarProductoCtrl.text);
    if (consulta.isEmpty) return _productos;

    return _productos
        .where(
          (producto) => _normalizarTexto(producto.nombre).contains(consulta),
        )
        .toList();
  }

  bool _esPrecioValido(double precio) => precio.isFinite && precio >= 0;

  String _formatearPrecio(double precio) {
    if (!precio.isFinite || precio < 0) return 'Precio inválido';
    return 'L. ${precio.toStringAsFixed(2)}';
  }

  void _seleccionarCliente(Cliente cliente) {
    setState(() {
      _clienteSeleccionado = cliente;
      _mostrarResultados = false;
      _buscarCtrl.clear();
    });
  }

  PedidoItem _crearUnidadItem({
    required String productoId,
    required String nombre,
    required double precioUnitario,
    required String imageUrl,
  }) {
    return PedidoItem(
      itemId: 'item-$productoId-${_siguienteSecuenciaItem++}',
      productoId: productoId,
      nombre: nombre,
      cantidad: 1,
      precioUnitario: precioUnitario,
      imageUrl: imageUrl,
      notaPersonalizacion: '',
      estadoElaboracion: EstadoElaboracionPedido.recibido,
    );
  }

  void _notificarItemsCambiados() {
    widget.onItemsCambiados?.call(List.unmodifiable(_itemsSeleccionados));
  }

  TextEditingController _obtenerControladorPersonalizacion(PedidoItem unidad) {
    return _personalizacionCtrls.putIfAbsent(
      unidad.itemId,
      () => TextEditingController(text: unidad.notaPersonalizacion),
    );
  }

  void _liberarControladoresDeItems(Iterable<String> itemIds) {
    for (final id in itemIds) {
      _personalizacionCtrls.remove(id)?.dispose();
    }
  }

  void _actualizarPersonalizacion(String itemId, String nota) {
    final indice = _itemsSeleccionados.indexWhere(
      (item) => item.itemId == itemId,
    );
    if (indice < 0) return;

    final actual = _itemsSeleccionados[indice];
    if (actual.notaPersonalizacion == nota) return;

    _itemsSeleccionados[indice] = actual.copyWith(notaPersonalizacion: nota);
    _notificarItemsCambiados();
  }

  Future<bool> _confirmarAccion({
    required String titulo,
    required String mensaje,
    required String textoConfirmar,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: _rojoMarca),
              child: Text(textoConfirmar),
            ),
          ],
        );
      },
    );
    return resultado ?? false;
  }

  List<_GrupoProductoPedido> _agruparItemsSeleccionados() {
    final grupos = <String, _GrupoProductoPedido>{};
    for (final item in _itemsSeleccionados) {
      final existente = grupos[item.productoId];
      if (existente == null) {
        grupos[item.productoId] = _GrupoProductoPedido(
          productoId: item.productoId,
          nombre: item.nombre,
          precioUnitario: item.precioUnitario,
          cantidad: item.cantidad,
          subtotal: item.subtotal,
          unidades: [item],
        );
      } else {
        grupos[item.productoId] = existente.acumular(item);
      }
    }
    return grupos.values.toList();
  }

  void _agregarProducto(Producto producto) {
    if (!_esPrecioValido(producto.precio)) {
      setState(() {
        _avisoProducto =
            'El producto "${producto.nombre}" tiene un precio inválido y no puede seleccionarse.';
      });
      return;
    }

    setState(() {
      _itemsSeleccionados.add(
        _crearUnidadItem(
          productoId: producto.id,
          nombre: producto.nombre,
          precioUnitario: producto.precio,
          imageUrl: producto.imageUrl ?? '',
        ),
      );
      _avisoProducto = null;
      _mostrarResultadosProductos = false;
      _buscarProductoCtrl.clear();
    });
    _notificarItemsCambiados();
  }

  List<int> _obtenerIndicesProducto(String productoId) {
    final indices = <int>[];
    for (var i = 0; i < _itemsSeleccionados.length; i++) {
      if (_itemsSeleccionados[i].productoId == productoId) {
        indices.add(i);
      }
    }
    return indices;
  }

  int? _buscarIndiceUnidadAEliminar(
    List<int> indicesProducto, {
    required bool soloSinPersonalizacion,
  }) {
    for (var i = indicesProducto.length - 1; i >= 0; i--) {
      final idx = indicesProducto[i];
      final item = _itemsSeleccionados[idx];
      if (soloSinPersonalizacion && item.notaPersonalizacion.trim().isNotEmpty) {
        continue;
      }
      if (item.estadoElaboracion == EstadoElaboracionPedido.recibido) {
        return idx;
      }
    }
    for (var i = indicesProducto.length - 1; i >= 0; i--) {
      final idx = indicesProducto[i];
      if (!soloSinPersonalizacion ||
          _itemsSeleccionados[idx].notaPersonalizacion.trim().isEmpty) {
        return idx;
      }
    }
    return null;
  }

  Future<void> _cambiarCantidad(String productoId, int delta) async {
    if (delta == 0) return;

    final indicesProducto = _obtenerIndicesProducto(productoId);
    if (indicesProducto.isEmpty) return;

    if (delta > 0) {
      final referencia = _itemsSeleccionados[indicesProducto.first];
      setState(() {
        for (var i = 0; i < delta; i++) {
          _itemsSeleccionados.add(
            _crearUnidadItem(
              productoId: referencia.productoId,
              nombre: referencia.nombre,
              precioUnitario: referencia.precioUnitario,
              imageUrl: referencia.imageUrl ?? '',
            ),
          );
        }
        _avisoProducto = null;
      });
      _notificarItemsCambiados();
      return;
    }

    if (indicesProducto.length <= 1) return;

    var indiceAEliminar = _buscarIndiceUnidadAEliminar(
      indicesProducto,
      soloSinPersonalizacion: true,
    );

    if (indiceAEliminar == null) {
      final nombreProducto = _itemsSeleccionados[indicesProducto.first].nombre;
      final confirmado = await _confirmarAccion(
        titulo: 'Disminuir cantidad',
        mensaje:
            'Todas las unidades de "$nombreProducto" tienen instrucciones de personalización. ¿Deseas eliminar una unidad y descartar sus instrucciones?',
        textoConfirmar: 'Eliminar unidad',
      );
      if (!confirmado || !mounted) return;

      final indicesActualizados = _obtenerIndicesProducto(productoId);
      if (indicesActualizados.length <= 1) return;

      indiceAEliminar = _buscarIndiceUnidadAEliminar(
        indicesActualizados,
        soloSinPersonalizacion: false,
      );
    }

    if (indiceAEliminar == null ||
        indiceAEliminar < 0 ||
        indiceAEliminar >= _itemsSeleccionados.length) {
      return;
    }

    final int indiceValido = indiceAEliminar;
    final itemEliminado = _itemsSeleccionados[indiceValido];
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _itemsSeleccionados.removeAt(indiceValido);
      _avisoProducto = null;
    });
    _liberarControladoresDeItems([itemEliminado.itemId]);
    _notificarItemsCambiados();
  }

  Future<void> _eliminarProducto(String productoId) async {
    final unidadesProducto = _itemsSeleccionados
        .where((item) => item.productoId == productoId)
        .toList();
    if (unidadesProducto.isEmpty) return;

    final tienePersonalizacion = unidadesProducto.any(
      (item) => item.notaPersonalizacion.trim().isNotEmpty,
    );
    if (tienePersonalizacion) {
      final confirmado = await _confirmarAccion(
        titulo: 'Eliminar producto',
        mensaje:
            'El producto "${unidadesProducto.first.nombre}" tiene unidades con instrucciones de personalización. ¿Deseas eliminarlo del pedido?',
        textoConfirmar: 'Eliminar',
      );
      if (!confirmado || !mounted) return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _itemsSeleccionados.removeWhere((item) => item.productoId == productoId);
      _avisoProducto = null;
    });
    _liberarControladoresDeItems(unidadesProducto.map((u) => u.itemId));
    _notificarItemsCambiados();
  }

  DateTime _soloFecha(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  Future<void> _seleccionarFechaEntrega() async {
    final hoy = _soloFecha(DateTime.now());
    final fechaInicial =
        (_fechaPrevistaEntrega != null &&
            !_fechaPrevistaEntrega!.isBefore(hoy))
        ? _fechaPrevistaEntrega!
        : hoy;

    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 5),
      helpText: 'Fecha prevista de entrega',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (seleccionada == null || !mounted) return;

    final normalizada = _soloFecha(seleccionada);
    if (normalizada.isBefore(hoy)) return;

    setState(() {
      _fechaPrevistaEntrega = normalizada;
    });
  }

  void _limpiarFechaEntrega() {
    setState(() {
      _fechaPrevistaEntrega = null;
    });
  }

  void _alCambiarCostoEnvio(String valor) {
    final limpio = valor.trim();
    if (limpio.isEmpty) {
      setState(() {
        _costoEnvioValido = 0.0;
        _errorCostoEnvio = null;
      });
      return;
    }

    final parsed = double.tryParse(limpio);
    if (parsed == null || !parsed.isFinite) {
      setState(() {
        _costoEnvioValido = null;
        _errorCostoEnvio = 'Ingresa un costo de envío válido.';
      });
      return;
    }

    if (parsed < 0) {
      setState(() {
        _costoEnvioValido = null;
        _errorCostoEnvio = 'El costo de envío no puede ser negativo.';
      });
      return;
    }

    setState(() {
      _costoEnvioValido = parsed;
      _errorCostoEnvio = null;
    });
  }

  void _alCambiarDescuento(String valor) {
    final limpio = valor.trim().replaceAll(',', '.');
    if (limpio.isEmpty) {
      setState(() {
        _descuentoPorcentajeValido = 0.0;
        _errorDescuento = null;
      });
      return;
    }

    final parsed = double.tryParse(limpio);
    if (parsed == null || !parsed.isFinite) {
      setState(() {
        _descuentoPorcentajeValido = null;
        _errorDescuento = 'Ingresa un porcentaje de descuento válido.';
      });
      return;
    }

    if (parsed < 0 || parsed > 100) {
      setState(() {
        _descuentoPorcentajeValido = null;
        _errorDescuento = 'El descuento debe estar entre 0 y 100%.';
      });
      return;
    }

    setState(() {
      _descuentoPorcentajeValido = parsed;
      _errorDescuento = null;
    });
  }

  String _formatearPorcentaje(double valor) {
    return valor % 1 == 0 ? valor.toStringAsFixed(0) : valor.toStringAsFixed(2);
  }

  void _iniciarNuevoPedido() {
    FocusManager.instance.primaryFocus?.unfocus();
    for (final ctrl in _personalizacionCtrls.values) {
      ctrl.dispose();
    }
    _personalizacionCtrls.clear();

    setState(() {
      _pedidoRegistrado = null;
      _mensajeExitoRegistro = null;
      _mensajeErrorRegistro = null;

      _clienteSeleccionado = null;
      _buscarCtrl.clear();
      _mostrarResultados = false;

      _itemsSeleccionados.clear();
      _buscarProductoCtrl.clear();
      _mostrarResultadosProductos = false;
      _avisoProducto = null;

      _fechaPrevistaEntrega = null;

      _costoEnvioCtrl.text = '120.00';
      _costoEnvioValido = 120.0;
      _errorCostoEnvio = null;

      _descuentoMayoristaActivo = false;
      _descuentoCtrl.text = '20';
      _descuentoPorcentajeValido = 20.0;
      _errorDescuento = null;
    });

    _notificarItemsCambiados();
  }

  Future<void> _registrarPedido() async {
    if (_guardandoPedido || _yaRegistrado) return;

    final cliente = _clienteSeleccionado;
    if (cliente == null ||
        cliente.id.trim().isEmpty ||
        cliente.nombre.trim().isEmpty) {
      setState(() {
        _mensajeErrorRegistro =
            'Selecciona un cliente válido antes de registrar el pedido.';
        _mensajeExitoRegistro = null;
      });
      return;
    }

    if (_itemsSeleccionados.isEmpty) {
      setState(() {
        _mensajeErrorRegistro =
            'Agrega al menos un producto antes de registrar el pedido.';
        _mensajeExitoRegistro = null;
      });
      return;
    }

    for (final item in _itemsSeleccionados) {
      if (!_esPrecioValido(item.precioUnitario) || item.cantidad < 1) {
        setState(() {
          _mensajeErrorRegistro =
              'Uno o más productos tienen un precio o cantidad inválida.';
          _mensajeExitoRegistro = null;
        });
        return;
      }
    }

    final envioValido = _costoEnvioValido;
    if (envioValido == null) {
      setState(() {
        _mensajeErrorRegistro =
            _errorCostoEnvio ?? 'Corrige el costo de envío antes de guardar.';
        _mensajeExitoRegistro = null;
      });
      return;
    }

    final descuentoValido =
        _descuentoMayoristaActivo ? _descuentoPorcentajeValido : 0.0;
    if (descuentoValido == null) {
      setState(() {
        _mensajeErrorRegistro =
            _errorDescuento ??
            'Corrige el porcentaje de descuento mayorista antes de guardar.';
        _mensajeExitoRegistro = null;
      });
      return;
    }

    final borrador = Pedido(
      id: '',
      numeroPedido: '',
      clienteId: cliente.id.trim(),
      clienteNombre: cliente.nombre.trim(),
      clienteTelefono: cliente.telefono.trim(),
      clienteDireccion: cliente.direccion.trim(),
      clienteDepartamento: cliente.departamento.trim(),
      items: List<PedidoItem>.from(_itemsSeleccionados),
      estadoEnvio: EstadoEnvioPedido.pendiente,
      costoEnvio: envioValido,
      borradorFactura: BorradorFacturaPedido(
        impuestoPorcentaje: 0.0,
        descuentoMayoristaActivo: _descuentoMayoristaActivo,
        descuentoPorcentaje: descuentoValido,
        costoEnvio: envioValido,
      ),
      facturado: false,
      ventaId: null,
      facturaNumero: null,
      fechaPrevistaEntrega: _fechaPrevistaEntrega,
      fechaEnvio: null,
      fechaEntrega: null,
      fechaFacturacion: null,
      createdAt: null,
      updatedAt: null,
    );

    try {
      PedidoController.validarBorradorParaCreacion(borrador);
    } on PedidoControllerException catch (e) {
      setState(() {
        _mensajeErrorRegistro = e.mensaje;
        _mensajeExitoRegistro = null;
      });
      return;
    }

    setState(() {
      _guardandoPedido = true;
      _mensajeErrorRegistro = null;
      _mensajeExitoRegistro = null;
    });

    try {
      final guardar =
          widget.onRegistrarPedido ??
          (Pedido p) => PedidoController.crearPedido(p);
      final pedidoRegistrado = await guardar(borrador);
      if (!mounted) return;

      final numero = pedidoRegistrado.numeroPedido.trim().isNotEmpty
          ? pedidoRegistrado.numeroPedido.trim()
          : pedidoRegistrado.id;
      setState(() {
        _pedidoRegistrado = pedidoRegistrado;
        _mensajeExitoRegistro = numero.isNotEmpty
            ? 'Pedido $numero registrado correctamente.'
            : 'Pedido registrado correctamente.';
      });
      try {
        widget.onPedidoRegistrado?.call(pedidoRegistrado);
      } catch (e, st) {
        debugPrint(
          'Error al ejecutar onPedidoRegistrado tras registrar el pedido: $e\n$st',
        );
        if (mounted) {
          setState(() {
            _mensajeErrorRegistro =
                'El pedido se registró correctamente, pero no se pudo cambiar automáticamente a la lista de pedidos.';
          });
        }
      }
    } on PedidoControllerException catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajeErrorRegistro = e.mensaje;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mensajeErrorRegistro =
            'No se pudo registrar el pedido. Intenta nuevamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _guardandoPedido = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esEscritorio = constraints.maxWidth >= _breakpointEscritorio;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirEncabezado(esEscritorio: esEscritorio),
            const SizedBox(height: 16),
            _construirSeccionCliente(esEscritorio: esEscritorio),
            const SizedBox(height: 16),
            _construirSeccionProductos(esEscritorio: esEscritorio),
            const SizedBox(height: 16),
            _construirSeccionEntregaYEnvio(esEscritorio: esEscritorio),
            const SizedBox(height: 16),
            _construirResumenTotalEstimado(esEscritorio: esEscritorio),
          ],
        );
      },
    );
  }

  Widget _construirEncabezado({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 28 : 20,
        vertical: esEscritorio ? 22 : 18,
      ),
      decoration: _decoracionTarjeta(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _rosaSuave,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _bordeSuave),
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: _rojoMarca,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nuevo pedido',
                  style: TextStyle(
                    fontSize: esEscritorio ? 22 : 19,
                    fontWeight: FontWeight.w800,
                    color: _negroElegante,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecciona un cliente existente y agrega los productos del pedido.',
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

  Widget _construirSeccionCliente({required bool esEscritorio}) {
    final clientesFiltrados = _filtrarClientes();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esEscritorio ? 24 : 18),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline_rounded, color: _rojoMarca, size: 22),
              SizedBox(width: 8),
              Text(
                'Cliente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _negroElegante,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_cargandoClientes)
            _construirTarjetaCargando('Cargando clientes...')
          else if (_errorClientes)
            _construirTarjetaError(
              mensaje: 'No se pudieron cargar los clientes',
              onReintentar: _cargarClientes,
            )
          else if (_clientes.isEmpty)
            _construirTarjetaVacia('No hay clientes registrados')
          else ...[
            _construirBuscadorClientes(),
            if (_mostrarResultados) ...[
              const SizedBox(height: 10),
              _construirResultadosClientes(clientesFiltrados),
            ],
            if (_clienteSeleccionado != null) ...[
              const SizedBox(height: 16),
              _construirDetalleClienteSeleccionado(
                _clienteSeleccionado!,
                esEscritorio: esEscritorio,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _construirSeccionProductos({required bool esEscritorio}) {
    final productosFiltrados = _filtrarProductos();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esEscritorio ? 24 : 18),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: _rojoMarca, size: 22),
              SizedBox(width: 8),
              Text(
                'Productos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _negroElegante,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_cargandoProductos)
            _construirTarjetaCargando('Cargando productos...')
          else if (_errorProductos)
            _construirTarjetaError(
              mensaje: 'No se pudieron cargar los productos',
              onReintentar: _cargarProductos,
            )
          else if (_productos.isEmpty)
            _construirTarjetaVacia('No hay productos registrados')
          else ...[
            _construirBuscadorProductos(),
            if (_mostrarResultadosProductos) ...[
              const SizedBox(height: 10),
              _construirResultadosProductos(productosFiltrados),
            ],
            if (_avisoProducto != null) ...[
              const SizedBox(height: 10),
              _construirAvisoDiscreto(_avisoProducto!),
            ],
            if (_itemsSeleccionados.isNotEmpty) ...[
              const SizedBox(height: 16),
              _construirListaProductosSeleccionados(
                esEscritorio: esEscritorio,
              ),
              const SizedBox(height: 14),
              _construirResumenSubtotal(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _construirBuscadorClientes() {
    final tieneTexto = _buscarCtrl.text.isNotEmpty;

    return TextField(
      controller: _buscarCtrl,
      onTap: () {
        if (!_mostrarResultados) {
          setState(() {
            _mostrarResultados = true;
          });
        }
      },
      onChanged: (_) {
        setState(() {
          _mostrarResultados = true;
        });
      },
      decoration: _decoracionCampoBusqueda(
        labelText: _clienteSeleccionado == null
            ? 'Buscar cliente por nombre'
            : 'Buscar otro cliente para cambiar',
        hintText: 'Escribe el nombre del cliente...',
        tieneTexto: tieneTexto,
        mostrandoResultados: _mostrarResultados,
        tooltipOcultar: 'Ocultar lista de clientes',
        tooltipMostrar: 'Mostrar lista de clientes',
        onLimpiar: () {
          setState(() {
            _buscarCtrl.clear();
            _mostrarResultados = true;
          });
        },
        onAlternarLista: () {
          setState(() {
            _mostrarResultados = !_mostrarResultados;
          });
        },
      ),
    );
  }

  Widget _construirBuscadorProductos() {
    final tieneTexto = _buscarProductoCtrl.text.isNotEmpty;

    return TextField(
      controller: _buscarProductoCtrl,
      onTap: () {
        if (!_mostrarResultadosProductos) {
          setState(() {
            _mostrarResultadosProductos = true;
          });
        }
      },
      onChanged: (_) {
        setState(() {
          _mostrarResultadosProductos = true;
        });
      },
      decoration: _decoracionCampoBusqueda(
        labelText: 'Buscar producto por nombre',
        hintText: 'Escribe el nombre del producto...',
        tieneTexto: tieneTexto,
        mostrandoResultados: _mostrarResultadosProductos,
        tooltipOcultar: 'Ocultar lista de productos',
        tooltipMostrar: 'Mostrar lista de productos',
        onLimpiar: () {
          setState(() {
            _buscarProductoCtrl.clear();
            _mostrarResultadosProductos = true;
          });
        },
        onAlternarLista: () {
          setState(() {
            _mostrarResultadosProductos = !_mostrarResultadosProductos;
          });
        },
      ),
    );
  }

  InputDecoration _decoracionCampoBusqueda({
    required String labelText,
    required String hintText,
    required bool tieneTexto,
    required bool mostrandoResultados,
    required String tooltipOcultar,
    required String tooltipMostrar,
    required VoidCallback onLimpiar,
    required VoidCallback onAlternarLista,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: const Icon(Icons.search_rounded, color: _rojoMarca),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tieneTexto)
            IconButton(
              tooltip: 'Limpiar búsqueda',
              icon: const Icon(Icons.close_rounded, color: _grisTexto),
              onPressed: onLimpiar,
            ),
          IconButton(
            tooltip: mostrandoResultados ? tooltipOcultar : tooltipMostrar,
            icon: Icon(
              mostrandoResultados
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: _grisTexto,
            ),
            onPressed: onAlternarLista,
          ),
        ],
      ),
      filled: true,
      fillColor: _rosaSuave.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _bordeSuave),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _bordeSuave),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _rojoMarca, width: 1.5),
      ),
    );
  }

  Widget _construirResultadosClientes(List<Cliente> clientesFiltrados) {
    if (clientesFiltrados.isEmpty) {
      return _construirSinCoincidencias('No se encontraron clientes');
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeSuave),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: clientesFiltrados.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: _bordeSuave),
        itemBuilder: (context, index) {
          final cliente = clientesFiltrados[index];
          final estaSeleccionado = _clienteSeleccionado?.id == cliente.id;
          final subtitulo = [
            if (cliente.telefono.trim().isNotEmpty) cliente.telefono.trim(),
            if (cliente.departamento.trim().isNotEmpty)
              cliente.departamento.trim(),
          ].join(' · ');

          return ListTile(
            dense: true,
            selected: estaSeleccionado,
            selectedTileColor: _rosaSuave.withValues(alpha: 0.7),
            leading: Icon(
              estaSeleccionado
                  ? Icons.check_circle_rounded
                  : Icons.person_outline_rounded,
              color: estaSeleccionado ? _rojoMarca : _grisTexto,
              size: 20,
            ),
            title: Text(
              cliente.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    estaSeleccionado ? FontWeight.w700 : FontWeight.w600,
                color: _negroElegante,
              ),
            ),
            subtitle: subtitulo.isNotEmpty
                ? Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: _grisTexto),
                  )
                : null,
            onTap: () => _seleccionarCliente(cliente),
          );
        },
      ),
    );
  }

  Widget _construirResultadosProductos(List<Producto> productosFiltrados) {
    if (productosFiltrados.isEmpty) {
      return _construirSinCoincidencias('No se encontraron productos');
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeSuave),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: productosFiltrados.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: _bordeSuave),
        itemBuilder: (context, index) {
          final producto = productosFiltrados[index];
          final indiceExistente = _itemsSeleccionados.indexWhere(
            (item) => item.productoId == producto.id,
          );
          final yaSeleccionado = indiceExistente >= 0;
          final precioValido = _esPrecioValido(producto.precio);
          final descripcion = producto.descripcion.trim();

          return ListTile(
            dense: true,
            selected: yaSeleccionado,
            selectedTileColor: _rosaSuave.withValues(alpha: 0.55),
            leading: Icon(
              yaSeleccionado
                  ? Icons.check_circle_rounded
                  : Icons.add_shopping_cart_rounded,
              color: yaSeleccionado
                  ? _rojoMarca
                  : (precioValido ? _grisTexto : Colors.orange),
              size: 20,
            ),
            title: Text(
              producto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: yaSeleccionado ? FontWeight.w700 : FontWeight.w600,
                color: _negroElegante,
              ),
            ),
            subtitle: descripcion.isNotEmpty
                ? Text(
                    descripcion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: _grisTexto),
                  )
                : null,
            trailing: Text(
              _formatearPrecio(producto.precio),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: precioValido ? _rojoMarca : Colors.orange.shade800,
              ),
            ),
            onTap: () => _agregarProducto(producto),
          );
        },
      ),
    );
  }

  Widget _construirListaProductosSeleccionados({required bool esEscritorio}) {
    final grupos = _agruparItemsSeleccionados();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < grupos.length; i++) ...[
            _construirFilaProductoSeleccionado(
              grupos[i],
              esEscritorio: esEscritorio,
            ),
            if (i < grupos.length - 1)
              const Divider(height: 1, color: _bordeSuave),
          ],
        ],
      ),
    );
  }

  Widget _construirFilaProductoSeleccionado(
    _GrupoProductoPedido item, {
    required bool esEscritorio,
  }) {
    final precioUnitarioTexto =
        'Precio unitario: ${_formatearPrecio(item.precioUnitario)}';
    final subtotalTexto = 'Subtotal: ${_formatearPrecio(item.subtotal)}';

    final controlesCantidad = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Disminuir cantidad',
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: item.cantidad > 1 ? _rojoMarca : _grisTexto,
          onPressed: item.cantidad > 1
              ? () => _cambiarCantidad(item.productoId, -1)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '${item.cantidad}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _negroElegante,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Aumentar cantidad',
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: _rojoMarca,
          onPressed: () => _cambiarCantidad(item.productoId, 1),
        ),
      ],
    );

    final botonEliminar = IconButton(
      tooltip: 'Eliminar producto',
      icon: const Icon(Icons.delete_outline_rounded, color: _rojoMarca),
      onPressed: () => _eliminarProducto(item.productoId),
    );

    return Padding(
      key: ValueKey<String>('grupo-producto-${item.productoId}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          esEscritorio
              ? Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: _rojoMarca,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _negroElegante,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            precioUnitarioTexto,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _grisTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    controlesCantidad,
                    const SizedBox(width: 12),
                    Text(
                      subtotalTexto,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _rojoMarca,
                      ),
                    ),
                    const SizedBox(width: 6),
                    botonEliminar,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: _rojoMarca,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: _negroElegante,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                precioUnitarioTexto,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: _grisTexto,
                                ),
                              ),
                            ],
                          ),
                        ),
                        botonEliminar,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        controlesCantidad,
                        const Spacer(),
                        Text(
                          subtotalTexto,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _rojoMarca,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 6),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: ValueKey<String>('personalizar-${item.productoId}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 6, bottom: 2),
              maintainState: true,
              iconColor: _rojoMarca,
              collapsedIconColor: _grisTexto,
              title: const Text(
                'Personalizar unidades',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _negroElegante,
                ),
              ),
              children: [
                for (var i = 0; i < item.unidades.length; i++) ...[
                  _construirFilaPersonalizacionUnidad(
                    item.unidades[i],
                    numeroUnidad: i + 1,
                  ),
                  if (i < item.unidades.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirFilaPersonalizacionUnidad(
    PedidoItem unidad, {
    required int numeroUnidad,
  }) {
    final controlador = _obtenerControladorPersonalizacion(unidad);

    return Container(
      key: ValueKey<String>('unidad-${unidad.itemId}'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unidad $numeroUnidad',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _rojoMarca,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controlador,
            onChanged: (valor) =>
                _actualizarPersonalizacion(unidad.itemId, valor),
            decoration: InputDecoration(
              labelText: 'Personalización / instrucciones',
              hintText: 'Ej. grabado, color, largo o detalle especial',
              isDense: true,
              filled: true,
              fillColor: _rosaSuave.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _bordeSuave),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _bordeSuave),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _rojoMarca, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirResumenSubtotal() {
    return Container(
      key: const ValueKey<String>('resumen-subtotal-general'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeSuave),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Subtotal general',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: _negroElegante,
              ),
            ),
          ),
          Text(
            _formatearPrecio(_subtotalGeneral),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _rojoMarca,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionEntregaYEnvio({required bool esEscritorio}) {
    final selectorFecha = InkWell(
      onTap: _seleccionarFechaEntrega,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha prevista de entrega (opcional)',
          prefixIcon: const Icon(
            Icons.calendar_today_outlined,
            color: _rojoMarca,
          ),
          suffixIcon: _fechaPrevistaEntrega != null
              ? IconButton(
                  tooltip: 'Limpiar fecha',
                  icon: const Icon(Icons.close_rounded, color: _grisTexto),
                  onPressed: _limpiarFechaEntrega,
                )
              : null,
          filled: true,
          fillColor: _rosaSuave.withValues(alpha: 0.35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bordeSuave),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bordeSuave),
          ),
        ),
        child: Text(
          _fechaPrevistaEntrega != null
              ? _formatearFecha(_fechaPrevistaEntrega!)
              : 'Sin fecha seleccionada',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: _fechaPrevistaEntrega != null
                ? FontWeight.w700
                : FontWeight.w500,
            color: _fechaPrevistaEntrega != null
                ? _negroElegante
                : _grisTexto,
          ),
        ),
      ),
    );

    final campoEnvio = TextField(
      controller: _costoEnvioCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: _alCambiarCostoEnvio,
      decoration: InputDecoration(
        labelText: 'Costo de envío (L.)',
        hintText: '0.00',
        errorText: _errorCostoEnvio,
        prefixIcon: const Icon(
          Icons.local_shipping_outlined,
          color: _rojoMarca,
        ),
        filled: true,
        fillColor: _rosaSuave.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _bordeSuave),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _bordeSuave),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _rojoMarca, width: 1.6),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esEscritorio ? 24 : 18),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Entrega y envío',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Define una fecha prevista opcional y el costo de envío para calcular el total.',
            style: TextStyle(fontSize: 13.5, color: _grisTexto),
          ),
          const SizedBox(height: 14),
          if (esEscritorio)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: selectorFecha),
                const SizedBox(width: 14),
                Expanded(child: campoEnvio),
              ],
            )
          else ...[
            selectorFecha,
            const SizedBox(height: 12),
            campoEnvio,
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Descuento mayorista',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
              ),
              Switch(
                value: _descuentoMayoristaActivo,
                activeTrackColor: _rojoMarca.withValues(alpha: 0.35),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return _rojoMarca;
                  }
                  return null;
                }),
                onChanged: (valor) {
                  setState(() {
                    _descuentoMayoristaActivo = valor;
                  });
                },
              ),
            ],
          ),
          if (_descuentoMayoristaActivo) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _descuentoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _alCambiarDescuento,
              decoration: InputDecoration(
                labelText: 'Descuento mayorista (%)',
                hintText: '20',
                errorText: _errorDescuento,
                prefixIcon: const Icon(
                  Icons.percent_rounded,
                  color: _rojoMarca,
                ),
                filled: true,
                fillColor: _rosaSuave.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _bordeSuave),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _bordeSuave),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _rojoMarca, width: 1.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirResumenTotalEstimado({required bool esEscritorio}) {
    final envioValido = _costoEnvioValido;
    final descuentoValido =
        _descuentoMayoristaActivo ? _descuentoPorcentajeValido : 0.0;
    final borrador = (envioValido != null && descuentoValido != null)
        ? BorradorFacturaPedido(
            impuestoPorcentaje: 0.0,
            descuentoMayoristaActivo: _descuentoMayoristaActivo,
            descuentoPorcentaje: descuentoValido,
            costoEnvio: envioValido,
          )
        : null;
    final descuentoMonto = borrador?.calcularDescuentoMonto(_subtotalGeneral);
    final totalEstimado = borrador?.calcularTotal(_subtotalGeneral);

    return Container(
      key: const ValueKey<String>('resumen-total-estimado'),
      width: double.infinity,
      padding: EdgeInsets.all(esEscritorio ? 24 : 18),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Subtotal productos',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _grisTexto,
                  ),
                ),
              ),
              Text(
                _formatearPrecio(_subtotalGeneral),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _negroElegante,
                ),
              ),
            ],
          ),
          if (_descuentoMayoristaActivo) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    descuentoValido != null
                        ? 'Descuento mayorista (${_formatearPorcentaje(descuentoValido)}%)'
                        : 'Descuento mayorista',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _grisTexto,
                    ),
                  ),
                ),
                Text(
                  descuentoMonto != null
                      ? '- ${_formatearPrecio(descuentoMonto)}'
                      : 'Valor inválido',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: descuentoMonto != null ? _negroElegante : _rojoMarca,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Costo de envío',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _grisTexto,
                  ),
                ),
              ),
              Text(
                envioValido != null
                    ? _formatearPrecio(envioValido)
                    : 'Valor inválido',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: envioValido != null ? _negroElegante : _rojoMarca,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: _bordeSuave),
          ),
          if (totalEstimado != null)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total estimado',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: _negroElegante,
                    ),
                  ),
                ),
                Text(
                  _formatearPrecio(totalEstimado),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _rojoMarca,
                  ),
                ),
              ],
            )
          else
            _construirAvisoDiscreto(
              envioValido == null
                  ? 'Corrige el costo de envío para calcular el total estimado.'
                  : 'Corrige el descuento mayorista para calcular el total estimado.',
            ),
          if (_mensajeErrorRegistro != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey<String>('banner-error-registro'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _mensajeErrorRegistro!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_mensajeExitoRegistro != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey<String>('banner-exito-registro'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _mensajeExitoRegistro!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const ValueKey<String>('boton-registrar-pedido'),
              onPressed: (_guardandoPedido || _yaRegistrado)
                  ? null
                  : _registrarPedido,
              style: ElevatedButton.styleFrom(
                backgroundColor: _rojoMarca,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _rojoMarca.withValues(alpha: 0.55),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _guardandoPedido
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _guardandoPedido
                    ? 'Registrando pedido...'
                    : 'Registrar pedido',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (_yaRegistrado) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                key: const ValueKey<String>('boton-nuevo-pedido'),
                onPressed: _iniciarNuevoPedido,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _rojoMarca,
                  side: const BorderSide(color: _rojoMarca, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text(
                  'Nuevo pedido',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirAvisoDiscreto(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bordeSuave),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _rojoMarca, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _negroElegante,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSinCoincidencias(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeSuave),
      ),
      child: Text(
        mensaje,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _grisTexto,
        ),
      ),
    );
  }

  Widget _construirTarjetaCargando(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _rojoMarca),
          const SizedBox(height: 12),
          Text(
            mensaje,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _grisTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaError({
    required String mensaje,
    required VoidCallback onReintentar,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: _rojoMarca,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaVacia(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _rojoMarca, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _negroElegante,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirDetalleClienteSeleccionado(
    Cliente cliente, {
    required bool esEscritorio,
  }) {
    final telefono = cliente.telefono.trim().isNotEmpty
        ? cliente.telefono.trim()
        : 'Sin teléfono registrado';
    final direccion = cliente.direccion.trim().isNotEmpty
        ? cliente.direccion.trim()
        : 'Sin dirección registrada';
    final departamento = cliente.departamento.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cliente.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _negroElegante,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarResultados = true;
                  });
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Cambiar'),
                style: TextButton.styleFrom(
                  foregroundColor: _rojoMarca,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (esEscritorio)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DatoCliente(
                    icono: Icons.phone_outlined,
                    etiqueta: 'Teléfono',
                    valor: telefono,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _DatoCliente(
                    icono: Icons.location_on_outlined,
                    etiqueta: 'Dirección',
                    valor: direccion,
                  ),
                ),
                if (departamento.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DatoCliente(
                      icono: Icons.map_outlined,
                      etiqueta: 'Departamento',
                      valor: departamento,
                    ),
                  ),
                ],
              ],
            )
          else ...[
            _DatoCliente(
              icono: Icons.phone_outlined,
              etiqueta: 'Teléfono',
              valor: telefono,
            ),
            const SizedBox(height: 8),
            _DatoCliente(
              icono: Icons.location_on_outlined,
              etiqueta: 'Dirección',
              valor: direccion,
            ),
            if (departamento.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DatoCliente(
                icono: Icons.map_outlined,
                etiqueta: 'Departamento',
                valor: departamento,
              ),
            ],
          ],
        ],
      ),
    );
  }

  BoxDecoration _decoracionTarjeta() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _bordeSuave),
      boxShadow: [
        BoxShadow(
          color: _rojoMarca.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _DatoCliente extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _DatoCliente({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 17, color: const Color(0xFFD9232E)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6E6566),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202020),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrupoProductoPedido {
  final String productoId;
  final String nombre;
  final double precioUnitario;
  final int cantidad;
  final double subtotal;
  final List<PedidoItem> unidades;

  const _GrupoProductoPedido({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    required this.cantidad,
    required this.subtotal,
    required this.unidades,
  });

  _GrupoProductoPedido acumular(PedidoItem item) {
    return _GrupoProductoPedido(
      productoId: productoId,
      nombre: nombre,
      precioUnitario: precioUnitario,
      cantidad: cantidad + item.cantidad,
      subtotal: subtotal + item.subtotal,
      unidades: [...unidades, item],
    );
  }
}
