import 'package:flutter/material.dart';

import '../controllers/cliente_controller.dart';
import '../controllers/producto_controller.dart';
import '../models/cliente.dart';
import '../models/pedido.dart';
import '../models/producto.dart';

class NuevoPedidoView extends StatefulWidget {
  final List<Cliente> clientes;
  final List<Producto>? productos;

  const NuevoPedidoView({
    super.key,
    this.clientes = const [],
    this.productos,
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
  String? _avisoProducto;

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

  void _agregarProducto(Producto producto) {
    if (!_esPrecioValido(producto.precio)) {
      setState(() {
        _avisoProducto =
            'El producto "${producto.nombre}" tiene un precio inválido y no puede seleccionarse.';
      });
      return;
    }

    final indiceExistente = _itemsSeleccionados.indexWhere(
      (item) => item.productoId == producto.id,
    );

    setState(() {
      if (indiceExistente >= 0) {
        final actual = _itemsSeleccionados[indiceExistente];
        _itemsSeleccionados[indiceExistente] = actual.copyWith(
          cantidad: actual.cantidad + 1,
        );
      } else {
        _itemsSeleccionados.add(
          PedidoItem(
            itemId: 'item-${producto.id}',
            productoId: producto.id,
            nombre: producto.nombre,
            cantidad: 1,
            precioUnitario: producto.precio,
            imageUrl: producto.imageUrl,
          ),
        );
      }
      _avisoProducto = null;
      _mostrarResultadosProductos = false;
      _buscarProductoCtrl.clear();
    });
  }

  void _cambiarCantidad(String productoId, int delta) {
    final indice = _itemsSeleccionados.indexWhere(
      (item) => item.productoId == productoId,
    );
    if (indice < 0) return;

    final actual = _itemsSeleccionados[indice];
    final nuevaCantidad = actual.cantidad + delta;
    if (nuevaCantidad < 1) return;

    setState(() {
      _itemsSeleccionados[indice] = actual.copyWith(cantidad: nuevaCantidad);
      _avisoProducto = null;
    });
  }

  void _eliminarProducto(String productoId) {
    setState(() {
      _itemsSeleccionados.removeWhere((item) => item.productoId == productoId);
      _avisoProducto = null;
    });
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
          for (var i = 0; i < _itemsSeleccionados.length; i++) ...[
            _construirFilaProductoSeleccionado(
              _itemsSeleccionados[i],
              esEscritorio: esEscritorio,
            ),
            if (i < _itemsSeleccionados.length - 1)
              const Divider(height: 1, color: _bordeSuave),
          ],
        ],
      ),
    );
  }

  Widget _construirFilaProductoSeleccionado(
    PedidoItem item, {
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: esEscritorio
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
                        style: const TextStyle(fontSize: 12.5, color: _grisTexto),
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
    );
  }

  Widget _construirResumenSubtotal() {
    return Container(
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
