import 'package:flutter/material.dart';

import '../models/pedido.dart';

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
  final List<Pedido> pedidos;

  const PedidosView({
    super.key,
    this.pedidos = const [],
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

  List<Pedido> get pedidos => widget.pedidos;

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
          setState(() {
            _subseccionActiva = opcion.seccion;
          });
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
        if (pedidos.isEmpty) {
          return _construirEstadoVacio(esEscritorio: esEscritorio);
        }
        return esEscritorio
            ? _construirTablaEscritorio()
            : _construirListaMovil();
      case _SubseccionPedidos.nuevoPedido:
        return _construirTarjetaInformativa(
          icono: Icons.add_circle_outline_rounded,
          titulo: 'Nuevo pedido',
          mensaje: 'Aquí podrás registrar nuevos pedidos',
          esEscritorio: esEscritorio,
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

    return Padding(
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
      padding: const EdgeInsets.all(16),
      decoration: _decoracionTarjeta(),
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
