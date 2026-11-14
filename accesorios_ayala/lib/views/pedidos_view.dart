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

  Future<void> _cargarPedidos() async {
    if (_usaListaExterna || _cargandoPedidos) return;

    setState(() {
      _cargandoPedidos = true;
      _errorCargaPedidos = null;
    });

    try {
      final cargados = await PedidoController.cargarPedidos();
      if (!mounted) return;
      setState(() {
        _pedidosCargados = cargados;
        _cargandoPedidos = false;
      });
    } on PedidoControllerException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCargaPedidos = e.mensaje;
        _cargandoPedidos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorCargaPedidos =
            'No se pudieron cargar los pedidos. Intenta nuevamente.';
        _cargandoPedidos = false;
      });
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
        return const NuevoPedidoView();
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
    final Widget contenido;
    if (_cargandoPedidos) {
      contenido = _construirEstadoCargando(esEscritorio: esEscritorio);
    } else if (_errorCargaPedidos != null) {
      contenido = _construirEstadoError(esEscritorio: esEscritorio);
    } else if (pedidos.isEmpty) {
      contenido = _construirEstadoVacio(esEscritorio: esEscritorio);
    } else {
      contenido = esEscritorio
          ? _construirTablaEscritorio()
          : _construirListaMovil();
    }

    if (_usaListaExterna) {
      return contenido;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _cargandoPedidos ? null : _cargarPedidos,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Actualizar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _rojoMarca,
              backgroundColor: Colors.white,
              side: const BorderSide(color: _bordeSuave),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
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

  Future<void> _mostrarDetallePedido(Pedido pedido) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final tamanioVentana = MediaQuery.sizeOf(dialogContext);
        final esVentanaEscritorio =
            tamanioVentana.width >= _breakpointEscritorio;
        final anchoMaximo = esVentanaEscritorio
            ? (tamanioVentana.width - 48).clamp(320.0, 1320.0)
            : (tamanioVentana.width - 24).clamp(280.0, 560.0);
        final altoMaximo =
            (tamanioVentana.height - (esVentanaEscritorio ? 48.0 : 32.0))
                .clamp(320.0, 820.0);

        return Dialog(
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
                                _numeroVisible(pedido),
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
                              child: _construirEtiquetasEstado(pedido),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
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
                          titulo: 'Productos (${pedido.items.length})',
                          child: pedido.items.isEmpty
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
                                      i < pedido.items.length;
                                      i++
                                    ) ...[
                                      _construirItemDetalle(
                                        pedido.items[i],
                                        esEscritorio: esDialogoEscritorio,
                                      ),
                                      if (i < pedido.items.length - 1)
                                        SizedBox(
                                          height: esDialogoEscritorio ? 8 : 10,
                                        ),
                                    ],
                                  ],
                                ),
                        );
                        final seccionResumen = _construirSeccionDetalle(
                          titulo: 'Resumen económico',
                          child: _construirResumenEconomicoDetalle(pedido),
                        );

                        return SingleChildScrollView(
                          padding: EdgeInsets.all(
                            esDialogoEscritorio ? 20 : 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _construirSeccionDetalle(
                                titulo: 'Información general',
                                child: esDialogoEscritorio
                                    ? _construirInfoGeneralEscritorio(pedido)
                                    : _construirInfoGeneralMovil(pedido),
                              ),
                              SizedBox(
                                height: esDialogoEscritorio ? 16 : 14,
                              ),
                              if (esDialogoEscritorio)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 7, child: seccionProductos),
                                    const SizedBox(width: 16),
                                    Expanded(flex: 4, child: seccionResumen),
                                  ],
                                )
                              else ...[
                                seccionProductos,
                                const SizedBox(height: 14),
                                seccionResumen,
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
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rojoMarca,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirInfoGeneralEscritorio(Pedido pedido) {
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
              _BloqueDatoDetalle(
                etiqueta: 'Entrega prevista',
                valor: _formatearFecha(pedido.fechaPrevistaEntrega),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirInfoGeneralMovil(Pedido pedido) {
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
        _FilaDatoDetalle(
          etiqueta: 'Entrega prevista',
          valor: _formatearFecha(pedido.fechaPrevistaEntrega),
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

  Widget _construirItemDetalle(
    PedidoItem item, {
    required bool esEscritorio,
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
              _ChipEstado(
                prefijo: 'Elaboración',
                etiqueta: item.estadoElaboracion.etiqueta,
                color: _colorProduccion(item.estadoElaboracion),
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
