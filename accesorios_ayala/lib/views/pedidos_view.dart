import 'package:flutter/material.dart';

import '../controllers/pedido_controller.dart';
import '../models/pedido.dart';
import 'nuevo_pedido_view.dart';

enum _SubseccionPedidos {
  resumen,
  pedidos,
  nuevoPedido,
  reportes,
  alertas,
}

class _OpcionSubmenuPedidos {
  final _SubseccionPedidos seccion;
  final String etiqueta;
  final IconData icono;

  const _OpcionSubmenuPedidos({
    required this.seccion,
    required this.etiqueta,
    required this.icono,
  });
}

class PedidosView extends StatefulWidget {
  final List<Pedido>? pedidos;

  const PedidosView({
    super.key,
    this.pedidos,
  });

  @override
  State<PedidosView> createState() => _PedidosViewState();
}

class _PedidosViewState extends State<PedidosView> {
  static const double _breakpointEscritorio = 760;
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  static const List<_OpcionSubmenuPedidos> _opcionesSubmenu = [
    _OpcionSubmenuPedidos(
      seccion: _SubseccionPedidos.resumen,
      etiqueta: 'Resumen',
      icono: Icons.dashboard_outlined,
    ),
    _OpcionSubmenuPedidos(
      seccion: _SubseccionPedidos.pedidos,
      etiqueta: 'Pedidos',
      icono: Icons.inventory_2_outlined,
    ),
    _OpcionSubmenuPedidos(
      seccion: _SubseccionPedidos.nuevoPedido,
      etiqueta: 'Nuevo pedido',
      icono: Icons.add_circle_outline_rounded,
    ),
    _OpcionSubmenuPedidos(
      seccion: _SubseccionPedidos.reportes,
      etiqueta: 'Reportes',
      icono: Icons.bar_chart_rounded,
    ),
    _OpcionSubmenuPedidos(
      seccion: _SubseccionPedidos.alertas,
      etiqueta: 'Alertas',
      icono: Icons.notifications_active_outlined,
    ),
  ];

  _SubseccionPedidos _subseccionActiva = _SubseccionPedidos.resumen;
  List<Pedido> _pedidosCargados = [];
  final Map<String, Pedido> _pedidosConfirmadosDuranteCarga = {};
  bool _cargandoPedidos = false;
  String? _errorCargaPedidos;

  bool get _usaListaExterna => widget.pedidos != null;

  List<Pedido> get pedidos => widget.pedidos ?? _pedidosCargados;

  @override
  void initState() {
    super.initState();
    if (!_usaListaExterna) {
      _cargarPedidos();
    }
  }

  @override
  void didUpdateWidget(covariant PedidosView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pedidos == null && oldWidget.pedidos != null) {
      _cargarPedidos();
    } else if (widget.pedidos != null && oldWidget.pedidos == null) {
      setState(() {
        _cargandoPedidos = false;
        _errorCargaPedidos = null;
      });
    }
  }

  Future<bool> _cargarPedidos() async {
    if (_usaListaExterna || _cargandoPedidos) return false;

    setState(() {
      _cargandoPedidos = true;
      _errorCargaPedidos = null;
    });

    try {
      final cargados = await PedidoController.cargarPedidos();
      if (!mounted) return false;
      final idsCargados = cargados.map((p) => p.id).toSet();
      final pendientesNoIncluidos = _pedidosConfirmadosDuranteCarga.values
          .where((p) => !idsCargados.contains(p.id))
          .toList(growable: false);
      _pedidosConfirmadosDuranteCarga.clear();
      setState(() {
        _pedidosCargados = [...pendientesNoIncluidos, ...cargados];
        _cargandoPedidos = false;
      });
      return true;
    } on PedidoControllerException catch (e) {
      _pedidosConfirmadosDuranteCarga.clear();
      if (!mounted) return false;
      setState(() {
        _errorCargaPedidos = e.mensaje;
        _cargandoPedidos = false;
      });
      return false;
    } catch (_) {
      _pedidosConfirmadosDuranteCarga.clear();
      if (!mounted) return false;
      setState(() {
        _errorCargaPedidos =
            'No se pudieron cargar los pedidos. Intenta nuevamente.';
        _cargandoPedidos = false;
      });
      return false;
    }
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String _numeroVisible(Pedido pedido) {
    final numero = pedido.numeroPedido.trim();
    return numero.isNotEmpty ? numero : 'Sin número';
  }

  String _totalVisible(Pedido pedido) =>
      'L. ${pedido.totalEstimado.toStringAsFixed(2)}';

  Color _colorProduccion(EstadoElaboracionPedido estado) {
    switch (estado) {
      case EstadoElaboracionPedido.recibido:
        return const Color(0xFF5C6BC0);
      case EstadoElaboracionPedido.enProceso:
        return const Color(0xFFEF6C00);
      case EstadoElaboracionPedido.terminado:
        return const Color(0xFF2E7D32);
    }
  }

  Color _colorEnvio(EstadoEnvioPedido estado) {
    switch (estado) {
      case EstadoEnvioPedido.pendiente:
        return const Color(0xFF6E6566);
      case EstadoEnvioPedido.enviado:
        return const Color(0xFF0277BD);
      case EstadoEnvioPedido.entregado:
        return const Color(0xFF2E7D32);
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
            const SizedBox(height: 14),
            _construirSubmenu(esEscritorio: esEscritorio),
            const SizedBox(height: 18),
            _construirContenidoActivo(esEscritorio: esEscritorio),
          ],
        );
      },
    );
  }

  Widget _construirSubmenu({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 14 : 10,
        vertical: 10,
      ),
      decoration: _decoracionTarjeta(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _opcionesSubmenu.length; i++) ...[
              _construirBotonSubmenu(_opcionesSubmenu[i]),
              if (i < _opcionesSubmenu.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _construirBotonSubmenu(_OpcionSubmenuPedidos opcion) {
    final estaActiva = opcion.seccion == _subseccionActiva;

    return TextButton.icon(
      onPressed: () {
        if (_subseccionActiva != opcion.seccion) {
          final veniaDeNuevoPedido =
              _subseccionActiva == _SubseccionPedidos.nuevoPedido;
          setState(() {
            _subseccionActiva = opcion.seccion;
          });
          if (veniaDeNuevoPedido &&
              opcion.seccion == _SubseccionPedidos.pedidos &&
              !_usaListaExterna) {
            _cargarPedidos();
          }
        }
      },
      icon: Icon(
        opcion.icono,
        size: 18,
        color: estaActiva ? _rojoMarca : _grisTexto,
      ),
      label: Text(
        opcion.etiqueta,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: estaActiva ? FontWeight.w700 : FontWeight.w600,
          color: estaActiva ? _rojoMarca : _negroElegante,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: estaActiva ? _rosaSuave : Colors.transparent,
        foregroundColor: _rojoMarca,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: estaActiva ? _bordeSuave : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _construirContenidoActivo({required bool esEscritorio}) {
    switch (_subseccionActiva) {
      case _SubseccionPedidos.resumen:
        return _construirTarjetaInformativa(
          icono: Icons.dashboard_outlined,
          titulo: 'Resumen de pedidos',
          mensaje: 'Aquí podrás consultar el estado general de tus pedidos',
          esEscritorio: esEscritorio,
        );
      case _SubseccionPedidos.pedidos:
        return _construirSeccionPedidos(esEscritorio: esEscritorio);
      case _SubseccionPedidos.nuevoPedido:
        return NuevoPedidoView(
          onPedidoRegistrado: _manejarPedidoRegistrado,
        );
      case _SubseccionPedidos.reportes:
        return _construirTarjetaInformativa(
          icono: Icons.bar_chart_rounded,
          titulo: 'Reportes de pedidos',
          mensaje: 'Aquí podrás consultar los reportes de tus pedidos',
          esEscritorio: esEscritorio,
        );
      case _SubseccionPedidos.alertas:
        return _construirTarjetaInformativa(
          icono: Icons.notifications_active_outlined,
          titulo: 'Alertas de pedidos',
          mensaje:
              'Aquí podrás consultar los pedidos próximos a vencer o atrasados',
          esEscritorio: esEscritorio,
        );
    }
  }

  Widget _construirTarjetaInformativa({
    required IconData icono,
    required String titulo,
    required String mensaje,
    required bool esEscritorio,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 32 : 20,
        vertical: esEscritorio ? 40 : 30,
      ),
      decoration: _decoracionTarjeta(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _rosaSuave,
              shape: BoxShape.circle,
              border: Border.all(color: _bordeSuave),
            ),
            child: Icon(
              icono,
              color: _rojoMarca,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _grisTexto,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEncabezado({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 28 : 20,
        vertical: esEscritorio ? 24 : 20,
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
              Icons.inventory_2_outlined,
              color: _rojoMarca,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pedidos',
                  style: TextStyle(
                    fontSize: esEscritorio ? 24 : 20,
                    fontWeight: FontWeight.w800,
                    color: _negroElegante,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aquí podrás consultar y administrar los pedidos de Accesorios Ayala.',
                  style: TextStyle(
                    fontSize: 14,
                    color: _grisTexto,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionPedidos({required bool esEscritorio}) {
    final tienePedidos = pedidos.isNotEmpty;
    final Widget contenido;
    if (tienePedidos) {
      contenido = esEscritorio
          ? _construirTablaEscritorio()
          : _construirListaMovil();
    } else if (_cargandoPedidos) {
      contenido = _construirEstadoCargando(esEscritorio: esEscritorio);
    } else if (_errorCargaPedidos != null) {
      contenido = _construirEstadoError(esEscritorio: esEscritorio);
    } else {
      contenido = _construirEstadoVacio(esEscritorio: esEscritorio);
    }

    if (_usaListaExterna) {
      return contenido;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (tienePedidos && _cargandoPedidos) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _rojoMarca,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Actualizando lista...',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _grisTexto,
                ),
              ),
              const SizedBox(width: 12),
            ],
            OutlinedButton.icon(
              onPressed: _cargandoPedidos ? null : _cargarPedidos,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Actualizar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _rojoMarca,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _bordeSuave),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        if (tienePedidos && !_cargandoPedidos && _errorCargaPedidos != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _rosaSuave.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bordeSuave),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: _rojoMarca,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No fue posible actualizar la lista desde Firestore. Se muestran los pedidos disponibles en memoria.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _negroElegante,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        contenido,
      ],
    );
  }

  Widget _construirEstadoCargando({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 32 : 20,
        vertical: esEscritorio ? 44 : 34,
      ),
      decoration: _decoracionTarjeta(),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _rojoMarca),
          SizedBox(height: 16),
          Text(
            'Cargando pedidos...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _grisTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoError({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 32 : 20,
        vertical: esEscritorio ? 44 : 34,
      ),
      decoration: _decoracionTarjeta(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _rosaSuave,
              shape: BoxShape.circle,
              border: Border.all(color: _bordeSuave),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _rojoMarca,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No se pudieron cargar los pedidos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorCargaPedidos ??
                'Ocurrió un error al consultar Firestore. Intenta nuevamente.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _grisTexto,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _cargandoPedidos ? null : _cargarPedidos,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoVacio({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 32 : 20,
        vertical: esEscritorio ? 44 : 34,
      ),
      decoration: _decoracionTarjeta(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _rosaSuave,
              shape: BoxShape.circle,
              border: Border.all(color: _bordeSuave),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _rojoMarca,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay pedidos registrados',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Los pedidos aparecerán aquí cuando estén disponibles.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _grisTexto,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTablaEscritorio() {
    return Container(
      width: double.infinity,
      decoration: _decoracionTarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _rosaSuave.withValues(alpha: 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: const Row(
              children: [
                Expanded(flex: 2, child: _EncabezadoColumna('N.º Pedido')),
                Expanded(flex: 3, child: _EncabezadoColumna('Cliente')),
                Expanded(flex: 2, child: _EncabezadoColumna('Entrega')),
                Expanded(flex: 4, child: _EncabezadoColumna('Estados')),
                Expanded(
                  flex: 2,
                  child: _EncabezadoColumna('Total', alineacionDerecha: true),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _bordeSuave),
          for (var i = 0; i < pedidos.length; i++) ...[
            _construirFilaEscritorio(pedidos[i]),
            if (i < pedidos.length - 1)
              const Divider(height: 1, color: _bordeSuave),
          ],
        ],
      ),
    );
  }

  Widget _construirFilaEscritorio(Pedido pedido) {
    final fechaEntrega = _formatearFecha(
      pedido.fechaEntrega ?? pedido.fechaPrevistaEntrega,
    );

    return InkWell(
      onTap: () => _mostrarDetallePedido(pedido),
      hoverColor: _rosaSuave.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                _numeroVisible(pedido),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _negroElegante,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                pedido.clienteNombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: _negroElegante),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                fechaEntrega,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: _grisTexto),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: _construirEtiquetasEstado(pedido),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                _totalVisible(pedido),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _rojoMarca,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirListaMovil() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < pedidos.length; i++) ...[
          _construirTarjetaMovil(pedidos[i]),
          if (i < pedidos.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _construirTarjetaMovil(Pedido pedido) {
    final fechaEntrega = _formatearFecha(
      pedido.fechaEntrega ?? pedido.fechaPrevistaEntrega,
    );

    return Container(
      decoration: _decoracionTarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDetallePedido(pedido),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _numeroVisible(pedido),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _negroElegante,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _totalVisible(pedido),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _rojoMarca,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pedido.clienteNombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _negroElegante,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: _grisTexto,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Entrega: $fechaEntrega',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _grisTexto),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _construirEtiquetasEstado(pedido),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatearDireccion(Pedido pedido) {
    final partes = [
      pedido.clienteDireccion.trim(),
      pedido.clienteDepartamento.trim(),
    ].where((parte) => parte.isNotEmpty).toList();
    return partes.isNotEmpty ? partes.join(', ') : 'Sin dirección';
  }

  void _actualizarPedidoEnLista(Pedido pedidoActualizado) {
    if (_usaListaExterna || !mounted) return;
    final indice = _pedidosCargados.indexWhere(
      (p) => p.id == pedidoActualizado.id,
    );
    if (indice == -1) return;
    setState(() {
      _pedidosCargados = [
        for (var i = 0; i < _pedidosCargados.length; i++)
          if (i == indice) pedidoActualizado else _pedidosCargados[i],
      ];
    });
  }

  void _eliminarPedidoDeLista(String pedidoId) {
    if (_usaListaExterna) return;
    setState(() {
      _pedidosCargados = _pedidosCargados
          .where((p) => p.id != pedidoId)
          .toList(growable: false);
    });
  }

  void _manejarPedidoRegistrado(Pedido pedido) {
    if (!mounted) return;
    if (_subseccionActiva == _SubseccionPedidos.pedidos) return;

    setState(() {
      _subseccionActiva = _SubseccionPedidos.pedidos;
      if (!_usaListaExterna) {
        if (_cargandoPedidos) {
          _pedidosConfirmadosDuranteCarga[pedido.id] = pedido;
        }
        final indiceExistente = _pedidosCargados.indexWhere(
          (p) => p.id == pedido.id,
        );
        if (indiceExistente == -1) {
          _pedidosCargados = [pedido, ..._pedidosCargados];
        } else {
          _pedidosCargados = [
            for (var i = 0; i < _pedidosCargados.length; i++)
              if (i == indiceExistente) pedido else _pedidosCargados[i],
          ];
        }
      }
    });

    if (!_usaListaExterna && !_cargandoPedidos) {
      _cargarPedidos();
    }

    final numero = _numeroVisible(pedido);
    final mensajeConfirmacion = pedido.numeroPedido.trim().isNotEmpty
        ? 'Pedido $numero registrado correctamente.'
        : 'Pedido registrado correctamente.';
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensajeConfirmacion)));
  }

  Future<void> _mostrarDetallePedido(Pedido pedido) async {
    var pedidoActual = pedido;
    final estadosProvisionales = <String, EstadoElaboracionPedido>{
      for (final item in pedidoActual.items) item.itemId: item.estadoElaboracion,
    };
    var guardando = false;
    var recargando = false;
    var eliminandoPedido = false;
    var confirmandoFacturacion = false;
    var facturandoPedido = false;
    var requiereRecarga = false;
    String? mensajeExito;
    String? mensajeError;
    var permitirRecargar = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hayCambiosProvisionales = pedidoActual.items.any(
              (item) =>
                  estadosProvisionales[item.itemId] != item.estadoElaboracion,
            );
            final pedidoProvisional = hayCambiosProvisionales
                ? pedidoActual.copyWith(
                    items: [
                      for (final item in pedidoActual.items)
                        item.copyWith(
                          estadoElaboracion:
                              estadosProvisionales[item.itemId] ??
                              item.estadoElaboracion,
                        ),
                    ],
                  )
                : pedidoActual;

            void aplicarErrorDeActualizacion({
              required String mensajeMostrado,
              required bool necesitaRecarga,
            }) {
              setDialogState(() {
                guardando = false;
                eliminandoPedido = false;
                confirmandoFacturacion = false;
                facturandoPedido = false;
                requiereRecarga = necesitaRecarga;
                mensajeExito = null;
                mensajeError = mensajeMostrado;
                permitirRecargar = necesitaRecarga && !_usaListaExterna;
              });
            }

            void manejarExcepcionActualizacion(Object error) {
              final sufijoListaExterna = _usaListaExterna
                  ? ' Cierra este detalle y actualiza la lista desde la vista que proporciona los pedidos antes de volver a guardar.'
                  : '';

              if (error is PedidoControllerException) {
                String mensajeMostrado;
                var necesitaRecarga = false;
                switch (error.tipo) {
                  case TipoErrorPedido.conflictoConcurrencia:
                    mensajeMostrado =
                        'Otro administrador modificó este pedido mientras lo editabas. Recárgalo antes de continuar.$sufijoListaExterna';
                    necesitaRecarga = true;
                  case TipoErrorPedido.actualizacionConfirmadaSinRecarga:
                    mensajeMostrado =
                        'Los cambios se confirmaron en Firestore, pero no se pudo recuperar la versión actualizada. Recarga el pedido para verificar su estado actual.$sufijoListaExterna';
                    necesitaRecarga = true;
                  case TipoErrorPedido.errorConexion:
                  case TipoErrorPedido.errorTransaccion:
                    mensajeMostrado =
                        'No se pudo confirmar si el guardado terminó en Firestore. No se reintentará automáticamente; recarga el pedido para verificar su estado actual.$sufijoListaExterna';
                    necesitaRecarga = true;
                  case TipoErrorPedido.datosInvalidos:
                  case TipoErrorPedido.permisosInsuficientes:
                  case TipoErrorPedido.pedidoNoEncontrado:
                  case TipoErrorPedido.pedidoExistente:
                    mensajeMostrado = error.mensaje;
                    necesitaRecarga = false;
                }
                aplicarErrorDeActualizacion(
                  mensajeMostrado: mensajeMostrado,
                  necesitaRecarga: necesitaRecarga,
                );
                return;
              }

              aplicarErrorDeActualizacion(
                mensajeMostrado:
                    'Ocurrió un error inesperado y no se pudo confirmar el resultado en Firestore. Recarga el pedido para verificar su estado actual.$sufijoListaExterna',
                necesitaRecarga: true,
              );
            }

            Future<void> guardarCambios() async {
              if (guardando ||
                  recargando ||
                  requiereRecarga ||
                  !hayCambiosProvisionales) {
                return;
              }

              final cambiosPorItemId = <String, EstadoElaboracionPedido>{
                for (final item in pedidoActual.items)
                  if (estadosProvisionales[item.itemId] != null &&
                      estadosProvisionales[item.itemId] !=
                          item.estadoElaboracion)
                    item.itemId: estadosProvisionales[item.itemId]!,
              };
              if (cambiosPorItemId.isEmpty) return;

              setDialogState(() {
                guardando = true;
                mensajeExito = null;
                mensajeError = null;
                permitirRecargar = false;
              });

              try {
                final pedidoConfirmado =
                    await PedidoController.actualizarEstadosProduccion(
                      pedidoId: pedidoActual.id,
                      estadosPorItemId: cambiosPorItemId,
                      updatedAtEsperado: pedidoActual.updatedAt,
                    );

                _actualizarPedidoEnLista(pedidoConfirmado);
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  pedidoActual = pedidoConfirmado;
                  estadosProvisionales
                    ..clear()
                    ..addEntries(
                      pedidoConfirmado.items.map(
                        (item) => MapEntry(item.itemId, item.estadoElaboracion),
                      ),
                    );
                  guardando = false;
                  requiereRecarga = false;
                  mensajeExito =
                      'Estados de producción guardados correctamente.';
                  mensajeError = null;
                  permitirRecargar = false;
                });
              } catch (e) {
                if (!dialogContext.mounted) return;
                manejarExcepcionActualizacion(e);
              }
            }

            Future<void> recargarPedido() async {
              if (guardando || recargando || _usaListaExterna) return;

              setDialogState(() {
                recargando = true;
                mensajeExito = null;
              });

              final recargaExitosa = await _cargarPedidos();
              if (!dialogContext.mounted) return;

              if (!recargaExitosa) {
                setDialogState(() {
                  recargando = false;
                  mensajeExito = null;
                  mensajeError =
                      _errorCargaPedidos ??
                      'No se pudo recargar el pedido desde Firestore. Intenta nuevamente.';
                  permitirRecargar = true;
                });
                return;
              }

              final indice = _pedidosCargados.indexWhere(
                (p) => p.id == pedidoActual.id,
              );
              if (indice != -1) {
                final recargado = _pedidosCargados[indice];
                setDialogState(() {
                  pedidoActual = recargado;
                  estadosProvisionales
                    ..clear()
                    ..addEntries(
                      recargado.items.map(
                        (item) => MapEntry(item.itemId, item.estadoElaboracion),
                      ),
                    );
                  recargando = false;
                  requiereRecarga = false;
                  mensajeError = null;
                  permitirRecargar = false;
                  mensajeExito =
                      'Pedido recargado con la versión más reciente de Firestore.';
                });
              } else {
                setDialogState(() {
                  recargando = false;
                  requiereRecarga = true;
                  mensajeExito = null;
                  mensajeError =
                      'El pedido ya no aparece en Firestore. Cierra este detalle para revisar la lista actualizada.';
                  permitirRecargar = true;
                });
              }
            }

            Future<void> editarFechaEntrega() async {
              if (guardando ||
                  recargando ||
                  eliminandoPedido ||
                  requiereRecarga ||
                  hayCambiosProvisionales ||
                  pedidoActual.facturado ||
                  pedidoActual.ventaId != null) {
                return;
              }

              final fechaInicial =
                  pedidoActual.fechaPrevistaEntrega ?? DateTime.now();
              final seleccionada = await showDatePicker(
                context: dialogContext,
                initialDate: fechaInicial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: 'Seleccionar fecha prevista de entrega',
              );
              if (seleccionada == null || !dialogContext.mounted) return;

              final nuevaFecha = DateTime.utc(
                seleccionada.year,
                seleccionada.month,
                seleccionada.day,
                18,
              );
              final fechaActual = pedidoActual.fechaPrevistaEntrega;
              final sinCambios =
                  fechaActual != null &&
                  fechaActual.year == nuevaFecha.year &&
                  fechaActual.month == nuevaFecha.month &&
                  fechaActual.day == nuevaFecha.day;
              if (sinCambios) return;

              final confirmado = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) {
                  return AlertDialog(
                    title: const Text('Confirmar nueva fecha de entrega'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha actual: ${_formatearFecha(pedidoActual.fechaPrevistaEntrega)}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nueva fecha: ${_formatearFecha(nuevaFecha)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rojoMarca,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Confirmar fecha'),
                      ),
                    ],
                  );
                },
              );
              if (confirmado != true || !dialogContext.mounted) return;

              setDialogState(() {
                guardando = true;
                mensajeExito = null;
                mensajeError = null;
                permitirRecargar = false;
              });

              try {
                final pedidoConfirmado =
                    await PedidoController.actualizarFechaPrevistaEntrega(
                      pedidoId: pedidoActual.id,
                      nuevaFechaPrevistaEntrega: nuevaFecha,
                      updatedAtEsperado: pedidoActual.updatedAt,
                    );

                _actualizarPedidoEnLista(pedidoConfirmado);
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  pedidoActual = pedidoConfirmado;
                  guardando = false;
                  requiereRecarga = false;
                  mensajeExito =
                      'Fecha prevista de entrega actualizada correctamente.';
                  mensajeError = null;
                  permitirRecargar = false;
                });
              } catch (e) {
                if (!dialogContext.mounted) return;
                manejarExcepcionActualizacion(e);
              }
            }

            Future<void> eliminarAccesorio(PedidoItem item) async {
              if (guardando ||
                  recargando ||
                  eliminandoPedido ||
                  requiereRecarga ||
                  hayCambiosProvisionales ||
                  pedidoActual.facturado ||
                  pedidoActual.ventaId != null ||
                  pedidoActual.items.length <= 1) {
                return;
              }

              final nota = item.notaPersonalizacion.trim();
              final confirmado = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) {
                  return AlertDialog(
                    title: const Text('Quitar accesorio'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Personalización: ${nota.isNotEmpty ? nota : 'Sin personalización'}',
                        ),
                        const SizedBox(height: 4),
                        Text('Cantidad: ${item.cantidad}'),
                        const SizedBox(height: 10),
                        const Text(
                          'Al quitar este accesorio se actualizarán los importes del pedido y su progreso de producción.',
                          style: TextStyle(fontSize: 13, color: _grisTexto),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rojoMarca,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Quitar accesorio'),
                      ),
                    ],
                  );
                },
              );
              if (confirmado != true || !dialogContext.mounted) return;

              setDialogState(() {
                guardando = true;
                mensajeExito = null;
                mensajeError = null;
                permitirRecargar = false;
              });

              try {
                final pedidoConfirmado =
                    await PedidoController.eliminarAccesorioPedido(
                      pedidoId: pedidoActual.id,
                      itemId: item.itemId,
                      updatedAtEsperado: pedidoActual.updatedAt,
                    );

                _actualizarPedidoEnLista(pedidoConfirmado);
                if (!dialogContext.mounted) return;

                setDialogState(() {
                  pedidoActual = pedidoConfirmado;
                  estadosProvisionales
                    ..clear()
                    ..addEntries(
                      pedidoConfirmado.items.map(
                        (it) => MapEntry(it.itemId, it.estadoElaboracion),
                      ),
                    );
                  guardando = false;
                  requiereRecarga = false;
                  mensajeExito =
                      'Accesorio quitado del pedido y totales actualizados.';
                  mensajeError = null;
                  permitirRecargar = false;
                });
              } catch (e) {
                if (!dialogContext.mounted) return;
                manejarExcepcionActualizacion(e);
              }
            }

            Future<void> eliminarPedidoCompleto() async {
              final elegibleParaEliminar =
                  !pedidoActual.facturado &&
                  pedidoActual.ventaId == null &&
                  pedidoActual.facturaNumero == null;
              if (guardando ||
                  recargando ||
                  eliminandoPedido ||
                  requiereRecarga ||
                  hayCambiosProvisionales ||
                  !elegibleParaEliminar) {
                return;
              }

              final numeroPedido = _numeroVisible(pedidoActual);
              final confirmado = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) {
                  return AlertDialog(
                    title: const Text('Eliminar pedido'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          numeroPedido,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text('Cliente: ${pedidoActual.clienteNombre}'),
                        const SizedBox(height: 10),
                        const Text(
                          'Esta acción eliminará el pedido de forma permanente y no se puede deshacer.',
                          style: TextStyle(fontSize: 13, color: _grisTexto),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Eliminar definitivamente'),
                      ),
                    ],
                  );
                },
              );
              if (confirmado != true || !dialogContext.mounted) return;

              setDialogState(() {
                eliminandoPedido = true;
                mensajeExito = null;
                mensajeError = null;
                permitirRecargar = false;
              });

              try {
                await PedidoController.eliminarPedido(
                  pedidoId: pedidoActual.id,
                  updatedAtEsperado: pedidoActual.updatedAt,
                );

                _eliminarPedidoDeLista(pedidoActual.id);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Pedido $numeroPedido eliminado definitivamente.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!dialogContext.mounted) return;
                manejarExcepcionActualizacion(e);
              }
            }

            final tamanioVentana = MediaQuery.sizeOf(dialogContext);
            final esVentanaEscritorio =
                tamanioVentana.width >= _breakpointEscritorio;
            final anchoMaximo = esVentanaEscritorio
                ? (tamanioVentana.width - 48).clamp(320.0, 1320.0)
                : (tamanioVentana.width - 24).clamp(280.0, 560.0);
            final altoMaximo =
                (tamanioVentana.height - (esVentanaEscritorio ? 48.0 : 32.0))
                    .clamp(320.0, 820.0);
            final bloqueadoPorOperacion =
                guardando ||
                recargando ||
                eliminandoPedido ||
                confirmandoFacturacion ||
                facturandoPedido;

            Future<void> facturarPedidoActual() async {
              if (confirmandoFacturacion ||
                  facturandoPedido ||
                  !pedidoActual.puedeFacturarse(
                    hayCambiosProvisionales: hayCambiosProvisionales,
                    operacionEnCurso: bloqueadoPorOperacion,
                    requiereRecarga: requiereRecarga,
                  )) {
                return;
              }

              setDialogState(() {
                confirmandoFacturacion = true;
              });

              bool? confirmado;
              try {
                final numeroPedido = _numeroVisible(pedidoActual);
                final totalEstimadoTexto =
                    'L ${pedidoActual.totalEstimado.toStringAsFixed(2)}';
                confirmado = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) {
                    return AlertDialog(
                      title: const Text('Confirmar facturación'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            numeroPedido,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text('Cliente: ${pedidoActual.clienteNombre}'),
                          const SizedBox(height: 4),
                          Text(
                            'Total estimado: $totalEstimadoTexto',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'El servidor calculará el total definitivo, asignará el número consecutivo de factura y marcará el pedido como facturado.',
                            style: TextStyle(fontSize: 13, color: _grisTexto),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(confirmContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _rojoMarca,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Facturar pedido'),
                        ),
                      ],
                    );
                  },
                );
              } catch (_) {
                confirmandoFacturacion = false;
                if (dialogContext.mounted) {
                  aplicarErrorDeActualizacion(
                    mensajeMostrado:
                        'No se pudo abrir la confirmación de facturación. Inténtalo nuevamente.',
                    necesitaRecarga: false,
                  );
                }
                return;
              }

              if (confirmado != true || !dialogContext.mounted) {
                confirmandoFacturacion = false;
                if (dialogContext.mounted) {
                  setDialogState(() {
                    confirmandoFacturacion = false;
                  });
                }
                return;
              }

              final sigueElegibleTrasConfirmar = pedidoActual.puedeFacturarse(
                hayCambiosProvisionales: hayCambiosProvisionales,
                operacionEnCurso:
                    guardando || recargando || eliminandoPedido || facturandoPedido,
                requiereRecarga: requiereRecarga,
              );
              if (!sigueElegibleTrasConfirmar) {
                setDialogState(() {
                  confirmandoFacturacion = false;
                });
                return;
              }

              setDialogState(() {
                confirmandoFacturacion = false;
                facturandoPedido = true;
                mensajeExito = null;
                mensajeError = null;
                permitirRecargar = false;
              });

              try {
                final pedidoConfirmado =
                    await PedidoController.facturarPedido(
                      pedidoId: pedidoActual.id,
                      updatedAtEsperado: pedidoActual.updatedAt,
                    );

                _actualizarPedidoEnLista(pedidoConfirmado);
                if (!dialogContext.mounted) return;

                final numeroFactura =
                    (pedidoConfirmado.facturaNumero ??
                            pedidoConfirmado.ventaId ??
                            '')
                        .trim();
                setDialogState(() {
                  pedidoActual = pedidoConfirmado;
                  estadosProvisionales
                    ..clear()
                    ..addEntries(
                      pedidoConfirmado.items.map(
                        (item) => MapEntry(item.itemId, item.estadoElaboracion),
                      ),
                    );
                  facturandoPedido = false;
                  requiereRecarga = false;
                  mensajeExito = numeroFactura.isNotEmpty
                      ? 'Factura $numeroFactura emitida correctamente.'
                      : 'Pedido facturado correctamente.';
                  mensajeError = null;
                  permitirRecargar = false;
                });
              } catch (e) {
                if (!dialogContext.mounted) {
                  facturandoPedido = false;
                  return;
                }
                manejarExcepcionActualizacion(e);
              }
            }
            final puedeMostrarEliminarPedido =
                !pedidoActual.facturado &&
                pedidoActual.ventaId == null &&
                pedidoActual.facturaNumero == null;

            return PopScope(
              canPop: !bloqueadoPorOperacion,
              child: Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: esVentanaEscritorio ? 24 : 12,
                  vertical: esVentanaEscritorio ? 24 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: _bordeSuave),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: anchoMaximo,
                    maxHeight: altoMaximo,
                  ),
                  child: SizedBox(
                    width: anchoMaximo,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            esVentanaEscritorio ? 22 : 16,
                            16,
                            12,
                            14,
                          ),
                          decoration: BoxDecoration(
                            color: _rosaSuave.withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                            border: const Border(
                              bottom: BorderSide(color: _bordeSuave),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _bordeSuave),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: _rojoMarca,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _numeroVisible(pedidoProvisional),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _negroElegante,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Detalle del pedido',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _grisTexto,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (esVentanaEscritorio) ...[
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _construirEtiquetasEstado(
                                      pedidoProvisional,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              IconButton(
                                onPressed: bloqueadoPorOperacion
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                tooltip: 'Cerrar',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: _grisTexto,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final esDialogoEscritorio =
                                  constraints.maxWidth >= 680;
                              final seccionProductos = _construirSeccionDetalle(
                                titulo:
                                    'Productos (${pedidoProvisional.items.length})',
                                child: pedidoProvisional.items.isEmpty
                                    ? const Text(
                                        'Este pedido no tiene productos registrados.',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: _grisTexto,
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (
                                            var i = 0;
                                            i < pedidoProvisional.items.length;
                                            i++
                                          ) ...[
                                            _construirItemDetalle(
                                              pedidoProvisional.items[i],
                                              esEscritorio: esDialogoEscritorio,
                                              onEliminar:
                                                  !bloqueadoPorOperacion &&
                                                      !requiereRecarga &&
                                                      !hayCambiosProvisionales &&
                                                      !pedidoActual.facturado &&
                                                      pedidoActual.ventaId ==
                                                          null &&
                                                      pedidoActual
                                                              .items
                                                              .length >
                                                          1
                                                  ? () => eliminarAccesorio(
                                                      pedidoProvisional
                                                          .items[i],
                                                    )
                                                  : null,
                                              onEstadoSeleccionado:
                                                  bloqueadoPorOperacion
                                                  ? null
                                                  : (nuevoEstado) {
                                                      final itemId =
                                                          pedidoProvisional
                                                              .items[i]
                                                              .itemId;
                                                      if (estadosProvisionales[itemId] ==
                                                          nuevoEstado) {
                                                        return;
                                                      }
                                                      setDialogState(() {
                                                        estadosProvisionales[itemId] =
                                                            nuevoEstado;
                                                        mensajeExito = null;
                                                        if (!requiereRecarga) {
                                                          mensajeError = null;
                                                          permitirRecargar =
                                                              false;
                                                        }
                                                      });
                                                    },
                                            ),
                                            if (i <
                                                pedidoProvisional.items.length -
                                                    1)
                                              SizedBox(
                                                height: esDialogoEscritorio
                                                    ? 8
                                                    : 10,
                                              ),
                                          ],
                                        ],
                                      ),
                              );
                              final seccionResumen = _construirSeccionDetalle(
                                titulo: 'Resumen económico',
                                child: _construirResumenEconomicoDetalle(
                                  pedidoProvisional,
                                ),
                              );
                              final puedeFacturar = pedidoActual
                                  .puedeFacturarse(
                                    hayCambiosProvisionales:
                                        hayCambiosProvisionales,
                                    operacionEnCurso: bloqueadoPorOperacion,
                                    requiereRecarga: requiereRecarga,
                                  );
                              final seccionFacturacion =
                                  _construirSeccionFacturacionDetalle(
                                    pedidoActual,
                                    puedeFacturar: puedeFacturar,
                                    facturandoPedido: facturandoPedido,
                                    hayCambiosProvisionales:
                                        hayCambiosProvisionales,
                                    bloqueadoPorOperacion:
                                        bloqueadoPorOperacion,
                                    requiereRecarga: requiereRecarga,
                                    onFacturarTap: puedeFacturar
                                        ? facturarPedidoActual
                                        : null,
                                  );

                              return SingleChildScrollView(
                                padding: EdgeInsets.all(
                                  esDialogoEscritorio ? 20 : 16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (mensajeError != null) ...[
                                      _construirBannerEstadoDetalle(
                                        mensaje: mensajeError!,
                                        esError: true,
                                        accionTexto: permitirRecargar
                                            ? (recargando
                                                  ? 'Recargando...'
                                                  : 'Recargar pedido')
                                            : null,
                                        onAccion:
                                            permitirRecargar &&
                                                !bloqueadoPorOperacion
                                            ? recargarPedido
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                    ] else if (mensajeExito != null) ...[
                                      _construirBannerEstadoDetalle(
                                        mensaje: mensajeExito!,
                                        esError: false,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    _construirSeccionDetalle(
                                      titulo: 'Información general',
                                      child: esDialogoEscritorio
                                          ? _construirInfoGeneralEscritorio(
                                              pedidoProvisional,
                                              onEditarFechaEntrega:
                                                  !bloqueadoPorOperacion &&
                                                      !requiereRecarga &&
                                                      !hayCambiosProvisionales &&
                                                      !pedidoActual.facturado &&
                                                      pedidoActual.ventaId ==
                                                          null
                                                  ? editarFechaEntrega
                                                  : null,
                                            )
                                          : _construirInfoGeneralMovil(
                                              pedidoProvisional,
                                              onEditarFechaEntrega:
                                                  !bloqueadoPorOperacion &&
                                                      !requiereRecarga &&
                                                      !hayCambiosProvisionales &&
                                                      !pedidoActual.facturado &&
                                                      pedidoActual.ventaId ==
                                                          null
                                                  ? editarFechaEntrega
                                                  : null,
                                            ),
                                    ),
                                    const SizedBox(height: 12),
                                    _construirSeccionProgresoProduccion(
                                      pedidoProvisional,
                                      esEscritorio: esDialogoEscritorio,
                                      hayCambiosSinGuardar:
                                          hayCambiosProvisionales,
                                    ),
                                    SizedBox(
                                      height: esDialogoEscritorio ? 16 : 14,
                                    ),
                                    if (esDialogoEscritorio)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 7,
                                            child: seccionProductos,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 4,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                seccionResumen,
                                                const SizedBox(height: 12),
                                                seccionFacturacion,
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      seccionProductos,
                                      const SizedBox(height: 14),
                                      seccionResumen,
                                      const SizedBox(height: 12),
                                      seccionFacturacion,
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: _bordeSuave)),
                          ),
                          child: Builder(
                            builder: (context) {
                              Widget? estadoPie;
                              if (guardando || eliminandoPedido) {
                                estadoPie = Row(
                                  children: [
                                    const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _rojoMarca,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        eliminandoPedido
                                            ? 'Eliminando pedido en Firestore...'
                                            : 'Guardando cambios en Firestore...',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: _grisTexto,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else if (requiereRecarga) {
                                estadoPie = const Row(
                                  children: [
                                    Icon(
                                      Icons.sync_problem_rounded,
                                      size: 16,
                                      color: Color(0xFF991B1B),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Recarga requerida antes de volver a guardar',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else if (hayCambiosProvisionales) {
                                estadoPie = const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: Color(0xFFB45309),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Cambios provisionales sin guardar',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              final botonEliminar = OutlinedButton.icon(
                                onPressed:
                                    !bloqueadoPorOperacion &&
                                        !requiereRecarga &&
                                        !hayCambiosProvisionales
                                    ? eliminarPedidoCompleto
                                    : null,
                                icon: const Icon(
                                  Icons.delete_forever_outlined,
                                  size: 18,
                                ),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    eliminandoPedido
                                        ? 'Eliminando...'
                                        : 'Eliminar pedido',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFB91C1C),
                                  disabledForegroundColor: _grisTexto,
                                  side: BorderSide(
                                    color:
                                        !bloqueadoPorOperacion &&
                                            !requiereRecarga &&
                                            !hayCambiosProvisionales
                                        ? const Color(0xFFFCA5A5)
                                        : _bordeSuave,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: esVentanaEscritorio ? 14 : 10,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );

                              final botonGuardar = ElevatedButton(
                                onPressed:
                                    hayCambiosProvisionales &&
                                        !bloqueadoPorOperacion &&
                                        !requiereRecarga
                                    ? guardarCambios
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _rojoMarca,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _bordeSuave,
                                  disabledForegroundColor: _grisTexto,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: esVentanaEscritorio ? 20 : 12,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    guardando
                                        ? 'Guardando...'
                                        : 'Guardar cambios',
                                  ),
                                ),
                              );

                              if (esVentanaEscritorio) {
                                return Row(
                                  children: [
                                    if (estadoPie != null)
                                      Expanded(child: estadoPie)
                                    else
                                      const Spacer(),
                                    const SizedBox(width: 12),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (puedeMostrarEliminarPedido) ...[
                                          botonEliminar,
                                          const SizedBox(width: 10),
                                        ],
                                        botonGuardar,
                                      ],
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (estadoPie != null) ...[
                                    estadoPie,
                                    const SizedBox(height: 10),
                                  ],
                                  Row(
                                    children: [
                                      if (puedeMostrarEliminarPedido) ...[
                                        Expanded(child: botonEliminar),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(child: botonGuardar),
                                    ],
                                  ),
                                ],
                              );
                            },
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
      },
    );
  }

  Widget _construirBannerEstadoDetalle({
    required String mensaje,
    required bool esError,
    String? accionTexto,
    VoidCallback? onAccion,
  }) {
    final fondo = esError ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final borde = esError ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0);
    final colorTexto = esError
        ? const Color(0xFF991B1B)
        : const Color(0xFF065F46);
    final icono = esError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icono, size: 18, color: colorTexto),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorTexto,
              ),
            ),
          ),
          if (accionTexto != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAccion,
              style: TextButton.styleFrom(
                foregroundColor: colorTexto,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                accionTexto,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirSeccionFacturacionDetalle(
    Pedido pedido, {
    required bool puedeFacturar,
    required bool facturandoPedido,
    required bool hayCambiosProvisionales,
    required bool bloqueadoPorOperacion,
    required bool requiereRecarga,
    required VoidCallback? onFacturarTap,
  }) {
    final yaFacturado = pedido.facturado || pedido.ventaId != null;
    final numeroFactura = (pedido.facturaNumero ?? '').trim();
    final ventaId = (pedido.ventaId ?? '').trim();

    String descripcionEstado;
    if (yaFacturado) {
      if (numeroFactura.isNotEmpty) {
        descripcionEstado =
            'Este pedido ya cuenta con la factura $numeroFactura y no puede generar otra.';
      } else if (ventaId.isNotEmpty) {
        descripcionEstado =
            'Este pedido ya está asociado a la venta $ventaId y no puede generar otra factura.';
      } else {
        descripcionEstado =
            'Este pedido ya fue facturado y no permite generar una segunda factura.';
      }
    } else if (facturandoPedido) {
      descripcionEstado = 'Emitiendo factura en el servidor...';
    } else if (bloqueadoPorOperacion) {
      descripcionEstado =
          'Espera a que termine la operación actual antes de facturar.';
    } else if (requiereRecarga) {
      descripcionEstado =
          'Recarga el pedido para verificar su estado en Firestore antes de facturar.';
    } else if (hayCambiosProvisionales) {
      descripcionEstado =
          'Guarda los cambios de producción pendientes antes de facturar.';
    } else if (!pedido.todosAccesoriosTerminados) {
      descripcionEstado =
          'Disponible únicamente cuando todos los accesorios estén terminados.';
    } else {
      descripcionEstado =
          'Todos los accesorios están terminados. Pedido listo para facturar.';
    }

    return _construirSeccionDetalle(
      titulo: 'Facturación del pedido',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (yaFacturado) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: Color(0xFF065F46),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      numeroFactura.isNotEmpty
                          ? 'Pedido facturado · $numeroFactura'
                          : 'Pedido facturado',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: puedeFacturar ? onFacturarTap : null,
            icon: facturandoPedido
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long_rounded, size: 18),
            label: Text(
              facturandoPedido ? 'Facturando...' : 'Facturar pedido',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _rojoMarca,
              disabledForegroundColor: _grisTexto.withValues(alpha: 0.65),
              side: BorderSide(
                color: puedeFacturar ? _rojoMarca : _bordeSuave,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descripcionEstado,
            style: const TextStyle(
              fontSize: 12,
              color: _grisTexto,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotonEditarFechaEntrega(VoidCallback? onEditarFechaEntrega) {
    return IconButton(
      onPressed: onEditarFechaEntrega,
      tooltip: 'Editar fecha de entrega',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        Icons.edit_calendar_outlined,
        size: 17,
        color: onEditarFechaEntrega != null
            ? _rojoMarca
            : _grisTexto.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _construirInfoGeneralEscritorio(
    Pedido pedido, {
    VoidCallback? onEditarFechaEntrega,
  }) {
    final telefono = pedido.clienteTelefono.trim().isNotEmpty
        ? pedido.clienteTelefono.trim()
        : 'Sin teléfono';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BloqueDatoDetalle(
                etiqueta: 'Cliente',
                valor: pedido.clienteNombre,
              ),
              const SizedBox(height: 10),
              _BloqueDatoDetalle(
                etiqueta: 'Teléfono',
                valor: telefono,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: _BloqueDatoDetalle(
            etiqueta: 'Dirección',
            valor: _formatearDireccion(pedido),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BloqueDatoDetalle(
                etiqueta: 'Fecha de creación',
                valor: _formatearFecha(pedido.createdAt),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _BloqueDatoDetalle(
                      etiqueta: 'Entrega prevista',
                      valor: _formatearFecha(pedido.fechaPrevistaEntrega),
                    ),
                  ),
                  _construirBotonEditarFechaEntrega(onEditarFechaEntrega),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirInfoGeneralMovil(
    Pedido pedido, {
    VoidCallback? onEditarFechaEntrega,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilaDatoDetalle(
          etiqueta: 'Cliente',
          valor: pedido.clienteNombre,
        ),
        _FilaDatoDetalle(
          etiqueta: 'Teléfono',
          valor: pedido.clienteTelefono.trim().isNotEmpty
              ? pedido.clienteTelefono.trim()
              : 'Sin teléfono',
        ),
        _FilaDatoDetalle(
          etiqueta: 'Dirección',
          valor: _formatearDireccion(pedido),
        ),
        _FilaDatoDetalle(
          etiqueta: 'Fecha de creación',
          valor: _formatearFecha(pedido.createdAt),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _FilaDatoDetalle(
                etiqueta: 'Entrega prevista',
                valor: _formatearFecha(pedido.fechaPrevistaEntrega),
              ),
            ),
            _construirBotonEditarFechaEntrega(onEditarFechaEntrega),
          ],
        ),
        const SizedBox(height: 8),
        _construirEtiquetasEstado(pedido),
      ],
    );
  }

  Widget _construirSeccionDetalle({
    required String titulo,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _construirSeccionProgresoProduccion(
    Pedido pedido, {
    required bool esEscritorio,
    bool hayCambiosSinGuardar = false,
  }) {
    var totalUnidades = 0;
    var unidadesTerminadas = 0;
    for (final item in pedido.items) {
      totalUnidades += item.cantidad;
      if (item.estadoElaboracion == EstadoElaboracionPedido.terminado) {
        unidadesTerminadas += item.cantidad;
      }
    }

    final progreso = totalUnidades == 0
        ? 0.0
        : (unidadesTerminadas / totalUnidades).clamp(0.0, 1.0);
    final porcentaje = totalUnidades == 0
        ? 0
        : ((unidadesTerminadas / totalUnidades) * 100).round();
    final colorProgreso = porcentaje == 100
        ? const Color(0xFF2E7D32)
        : _rojoMarca;
    final textoAccesorios = totalUnidades == 1
        ? '$unidadesTerminadas de $totalUnidades accesorio terminado'
        : '$unidadesTerminadas de $totalUnidades accesorios terminados';

    return _construirSeccionDetalle(
      titulo: 'Progreso de producción',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                textoAccesorios,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _negroElegante,
                ),
              ),
              Text(
                '$porcentaje %',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colorProgreso,
                ),
              ),
            ],
          ),
          SizedBox(height: esEscritorio ? 8 : 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 9,
              backgroundColor: _rosaSuave,
              valueColor: AlwaysStoppedAnimation<Color>(colorProgreso),
            ),
          ),
          if (hayCambiosSinGuardar) ...[
            const SizedBox(height: 8),
            const Text(
              'Vista previa local: los cambios seleccionados aún no se han guardado en Firestore.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB45309),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirItemDetalle(
    PedidoItem item, {
    required bool esEscritorio,
    ValueChanged<EstadoElaboracionPedido>? onEstadoSeleccionado,
    VoidCallback? onEliminar,
  }) {
    final nota = item.notaPersonalizacion.trim();

    return Container(
      padding: EdgeInsets.all(esEscritorio ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.nombre,
                  style: TextStyle(
                    fontSize: esEscritorio ? 14 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEliminar,
                tooltip: 'Quitar accesorio',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: onEliminar != null
                      ? _rojoMarca
                      : _grisTexto.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          SizedBox(height: esEscritorio ? 6 : 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(
                'Cantidad: ${item.cantidad}',
                style: const TextStyle(fontSize: 13, color: _grisTexto),
              ),
              Text(
                'Precio unitario: L. ${item.precioUnitario.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: _grisTexto),
              ),
            ],
          ),
          SizedBox(height: esEscritorio ? 7 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final estado in EstadoElaboracionPedido.values)
                _MiniEstadoProduccion(
                  estado: estado,
                  activo: estado == item.estadoElaboracion,
                  completado: estado.index < item.estadoElaboracion.index,
                  color: _colorProduccion(estado),
                  onTap: onEstadoSeleccionado != null
                      ? () => onEstadoSeleccionado(estado)
                      : null,
                ),
            ],
          ),
          SizedBox(height: esEscritorio ? 6 : 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: esEscritorio ? 7 : 10,
            ),
            decoration: BoxDecoration(
              color: _rosaSuave.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _bordeSuave),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personalización',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _grisTexto,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nota.isNotEmpty ? nota : 'Sin personalización',
                  style: TextStyle(
                    fontSize: 13,
                    color: nota.isNotEmpty ? _negroElegante : _grisTexto,
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

  Widget _construirResumenEconomicoDetalle(Pedido pedido) {
    final subtotal = pedido.subtotalProductos;
    final descuento = pedido.borradorFactura.calcularDescuentoMonto(subtotal);
    final costoEnvio = pedido.borradorFactura.costoEnvio;
    final total = pedido.totalEstimado;

    return Column(
      children: [
        _FilaMontoDetalle(
          etiqueta: 'Subtotal',
          monto: 'L. ${subtotal.toStringAsFixed(2)}',
        ),
        if (pedido.borradorFactura.descuentoMayoristaActivo) ...[
          const SizedBox(height: 6),
          _FilaMontoDetalle(
            etiqueta:
                'Descuento mayorista (${pedido.borradorFactura.descuentoPorcentaje.toStringAsFixed(0)}%)',
            monto: '- L. ${descuento.toStringAsFixed(2)}',
          ),
        ],
        const SizedBox(height: 6),
        _FilaMontoDetalle(
          etiqueta: 'Costo de envío',
          monto: 'L. ${costoEnvio.toStringAsFixed(2)}',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: _bordeSuave),
        ),
        _FilaMontoDetalle(
          etiqueta: 'Total estimado',
          monto: 'L. ${total.toStringAsFixed(2)}',
          destacado: true,
        ),
      ],
    );
  }

  Widget _construirEtiquetasEstado(Pedido pedido) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _ChipEstado(
          prefijo: 'Producción',
          etiqueta: pedido.estadoProduccion.etiqueta,
          color: _colorProduccion(pedido.estadoProduccion),
        ),
        _ChipEstado(
          prefijo: 'Envío',
          etiqueta: pedido.estadoEnvio.etiqueta,
          color: _colorEnvio(pedido.estadoEnvio),
        ),
      ],
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

class _EncabezadoColumna extends StatelessWidget {
  final String texto;
  final bool alineacionDerecha;

  const _EncabezadoColumna(this.texto, {this.alineacionDerecha = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      textAlign: alineacionDerecha ? TextAlign.right : TextAlign.left,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6E6566),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final String prefijo;
  final String etiqueta;
  final Color color;

  const _ChipEstado({
    required this.prefijo,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '$prefijo: $etiqueta',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FilaDatoDetalle extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaDatoDetalle({
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 122,
            child: Text(
              '$etiqueta:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6E6566),
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF202020),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BloqueDatoDetalle extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _BloqueDatoDetalle({
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
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
    );
  }
}

class _FilaMontoDetalle extends StatelessWidget {
  final String etiqueta;
  final String monto;
  final bool destacado;

  const _FilaMontoDetalle({
    required this.etiqueta,
    required this.monto,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: TextStyle(
              fontSize: destacado ? 14.5 : 13.5,
              fontWeight: destacado ? FontWeight.w800 : FontWeight.w600,
              color: destacado
                  ? const Color(0xFF202020)
                  : const Color(0xFF6E6566),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          monto,
          style: TextStyle(
            fontSize: destacado ? 15.5 : 13.5,
            fontWeight: destacado ? FontWeight.w800 : FontWeight.w700,
            color: destacado
                ? const Color(0xFFD9232E)
                : const Color(0xFF202020),
          ),
        ),
      ],
    );
  }
}

class _MiniEstadoProduccion extends StatelessWidget {
  final EstadoElaboracionPedido estado;
  final bool activo;
  final bool completado;
  final Color color;
  final VoidCallback? onTap;

  const _MiniEstadoProduccion({
    required this.estado,
    required this.activo,
    required this.completado,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icono;
    if (activo) {
      icono = Icons.radio_button_checked_rounded;
    } else if (completado) {
      icono = Icons.check_rounded;
    } else {
      icono = Icons.radio_button_unchecked_rounded;
    }

    final Color colorTexto;
    final Color colorFondo;
    final Color colorBorde;

    if (activo) {
      colorTexto = color;
      colorFondo = color.withValues(alpha: 0.14);
      colorBorde = color.withValues(alpha: 0.55);
    } else if (completado) {
      colorTexto = color.withValues(alpha: 0.80);
      colorFondo = color.withValues(alpha: 0.06);
      colorBorde = color.withValues(alpha: 0.25);
    } else {
      colorTexto = const Color(0xFF8C8586);
      colorFondo = const Color(0xFFF5F5F5);
      colorBorde = const Color(0xFFE0E0E0);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorFondo,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorBorde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 13, color: colorTexto),
              const SizedBox(width: 4),
              Text(
                estado.etiqueta,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                  color: colorTexto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
