import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:accesorios_ayala/views/vista_previa_recibo_view.dart';

import '../controllers/auth_controller.dart';
import '../models/cliente.dart';
import 'lista_clientes_view.dart';
import 'lista_productos_view.dart';
import 'pedidos_view.dart';
import 'seleccionar_cliente_view.dart';
import 'seleccionar_productos_view.dart';
import 'resumen_ventas_view.dart';

enum _AccionMenu {
  inicio,
  productos,
  recibos,
  ventas,
  clientes,
  pedidos,
  cerrarSesion,
}

class _OpcionMenu {
  final _AccionMenu accion;
  final String etiqueta;
  final IconData icono;

  const _OpcionMenu({
    required this.accion,
    required this.etiqueta,
    required this.icono,
  });
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const double _breakpointMenuEscritorio = 1040;
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _fondoClaro = Color(0xFFFAFAFA);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  static const List<_OpcionMenu> _opcionesNavegacion = [
    _OpcionMenu(
      accion: _AccionMenu.inicio,
      etiqueta: 'Inicio',
      icono: Icons.home_outlined,
    ),
    _OpcionMenu(
      accion: _AccionMenu.productos,
      etiqueta: 'Productos',
      icono: Icons.shopping_bag_outlined,
    ),
    _OpcionMenu(
      accion: _AccionMenu.recibos,
      etiqueta: 'Facturación',
      icono: Icons.receipt_long_outlined,
    ),
    _OpcionMenu(
      accion: _AccionMenu.ventas,
      etiqueta: 'Ventas',
      icono: Icons.bar_chart_rounded,
    ),
    _OpcionMenu(
      accion: _AccionMenu.clientes,
      etiqueta: 'Clientes',
      icono: Icons.people_outline_rounded,
    ),
    _OpcionMenu(
      accion: _AccionMenu.pedidos,
      etiqueta: 'Pedidos',
      icono: Icons.inventory_2_outlined,
    ),
  ];

  bool _cerrandoSesion = false;
  _AccionMenu _seccionActiva = _AccionMenu.inicio;
  Cliente? _clienteFacturacion;
  List<Map<String, dynamic>>? _productosFacturacion;
  bool _mostrandoVistaPreviaFactura = false;
  EstadoFacturaPrevia? _estadoFactura;

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    if (_cerrandoSesion) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Deseas cerrar tu sesión administrativa?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _cerrandoSesion = true;
    });

    try {
      await AuthController.cerrarSesion();
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cerrar la sesión. Intenta nuevamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cerrandoSesion = false;
        });
      }
    }
  }

  void _abrirVistaPreviaFactura(
    List<Map<String, dynamic>> productosSeleccionados,
  ) {
    setState(() {
      _productosFacturacion = productosSeleccionados;
      _mostrandoVistaPreviaFactura = true;
    });
  }

  void _manejarAccionMenu(_AccionMenu accion, BuildContext context) {
    switch (accion) {
      case _AccionMenu.inicio:
        if (_seccionActiva != _AccionMenu.inicio) {
          setState(() {
            _seccionActiva = _AccionMenu.inicio;
          });
        }
        return;
      case _AccionMenu.productos:
        if (_seccionActiva != _AccionMenu.productos) {
          setState(() {
            _seccionActiva = _AccionMenu.productos;
          });
        }
        return;
      case _AccionMenu.recibos:
        if (_seccionActiva != _AccionMenu.recibos) {
          setState(() {
            _seccionActiva = _AccionMenu.recibos;
          });
        }
        return;
      case _AccionMenu.ventas:
        if (_seccionActiva != _AccionMenu.ventas) {
          setState(() {
            _seccionActiva = _AccionMenu.ventas;
          });
        }
        return;
      case _AccionMenu.clientes:
        if (_seccionActiva != _AccionMenu.clientes) {
          setState(() {
            _seccionActiva = _AccionMenu.clientes;
          });
        }
        return;
      case _AccionMenu.pedidos:
        if (_seccionActiva != _AccionMenu.pedidos) {
          setState(() {
            _seccionActiva = _AccionMenu.pedidos;
          });
        }
        return;
      case _AccionMenu.cerrarSesion:
        _confirmarCerrarSesion(context);
        return;
    }
  }

  String? _obtenerCorreoActivo() {
    final correo = FirebaseAuth.instance.currentUser?.email?.trim();
    if (correo == null || correo.isEmpty) return null;
    return correo;
  }

  @override
  Widget build(BuildContext context) {
    final anchoVentana = MediaQuery.sizeOf(context).width;
    final esMenuEscritorio = anchoVentana >= _breakpointMenuEscritorio;
    final correoActivo = _obtenerCorreoActivo();

    return Scaffold(
      backgroundColor: _fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _rojoMarca),
        shape: const Border(bottom: BorderSide(color: _bordeSuave, width: 1)),
        title: Row(
          children: [
            const Icon(Icons.diamond_outlined, color: _rojoMarca, size: 22),
            const SizedBox(width: 10),
            if (esMenuEscritorio) ...[
              const Text(
                'Accesorios Ayala',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _rojoMarca,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _opcionesNavegacion
                        .map(
                          (opcion) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _construirBotonMenuEscritorio(
                              opcion: opcion,
                              context: context,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ] else
              const Flexible(
                child: Text(
                  'Accesorios Ayala',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _rojoMarca,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
          ],
        ),
        actions: esMenuEscritorio
            ? [
                if (correoActivo != null) ...[
                  Center(
                    child: Tooltip(
                      message: correoActivo,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _rosaSuave.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _bordeSuave),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: _rojoMarca,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  correoActivo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: _grisTexto,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: _rojoMarca),
                    tooltip: 'Cerrar sesión',
                    onPressed: _cerrandoSesion
                        ? null
                        : () => _confirmarCerrarSesion(context),
                  ),
                ),
              ]
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _construirMenuMovil(
                    context: context,
                    correoActivo: correoActivo,
                  ),
                ),
              ],
      ),
      body: Stack(
        children: [
          // Fondo claro elegante con matices sutiles
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, _fondoClaro, _rosaSuave],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ancho = constraints.maxWidth;
                final esEscritorio = ancho >= 760;
                final paddingHorizontal = esEscritorio ? 32.0 : 16.0;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: paddingHorizontal,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_seccionActiva == _AccionMenu.ventas)
                            const ResumenVentasView(integrado: true)
                          else if (_seccionActiva == _AccionMenu.productos)
                            const ListaProductosView(integrado: true)
                          else if (_seccionActiva == _AccionMenu.clientes)
                            const ListaClientesView(integrado: true)
                          else if (_seccionActiva == _AccionMenu.pedidos)
                            const PedidosView()
                          else if (_seccionActiva == _AccionMenu.recibos)
                            if (_clienteFacturacion == null)
                              SeleccionarClienteView(
                                integrado: true,
                                onClienteSeleccionado: (cliente) {
                                  setState(() {
                                    if (_estadoFactura?.ventaGuardada == true) {
                                      _productosFacturacion = null;
                                    }
                                    _clienteFacturacion = cliente;
                                    _mostrandoVistaPreviaFactura = false;
                                    _estadoFactura = null;
                                  });
                                },
                              )
                            else if (!_mostrandoVistaPreviaFactura ||
                                _productosFacturacion == null)
                              SeleccionarProductosView(
                                integrado: true,
                                seleccionInicial: _productosFacturacion,
                                onVolver: () {
                                  setState(() {
                                    _clienteFacturacion = null;
                                    _mostrandoVistaPreviaFactura = false;
                                  });
                                },
                                onContinuar: (seleccionados) {
                                  _abrirVistaPreviaFactura(seleccionados);
                                },
                              )
                            else
                              VistaPreviaReciboView(
                                integrado: true,
                                cliente: _clienteFacturacion!,
                                seleccionados: _productosFacturacion!,
                                estadoInicial: _estadoFactura,
                                onEstadoCambiado: (estado) {
                                  _estadoFactura = estado;
                                },
                                onVolver: () {
                                  setState(() {
                                    _mostrandoVistaPreviaFactura = false;
                                  });
                                },
                              )
                          else ...[
                            _construirEncabezadoBienvenida(
                              esEscritorio: esEscritorio,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotonMenuEscritorio({
    required _OpcionMenu opcion,
    required BuildContext context,
  }) {
    final estaActiva = opcion.accion == _seccionActiva;

    return TextButton.icon(
      onPressed: () => _manejarAccionMenu(opcion.accion, context),
      icon: Icon(
        opcion.icono,
        size: 18,
        color: estaActiva ? _rojoMarca : _grisTexto,
      ),
      label: Text(
        opcion.etiqueta,
        style: TextStyle(
          fontSize: 14,
          fontWeight: estaActiva ? FontWeight.w700 : FontWeight.w600,
          color: estaActiva ? _rojoMarca : _negroElegante,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: estaActiva ? _rosaSuave : Colors.transparent,
        foregroundColor: _rojoMarca,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: estaActiva ? _bordeSuave : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _construirMenuMovil({
    required BuildContext context,
    required String? correoActivo,
  }) {
    return PopupMenuButton<_AccionMenu>(
      icon: const Icon(Icons.more_vert_rounded, color: _rojoMarca),
      tooltip: 'Menú administrativo',
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _bordeSuave),
      ),
      onSelected: (accion) => _manejarAccionMenu(accion, context),
      itemBuilder: (_) => [
        if (correoActivo != null) ...[
          PopupMenuItem<_AccionMenu>(
            enabled: false,
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: _rojoMarca,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    correoActivo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _grisTexto,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        ..._opcionesNavegacion.map((opcion) {
          final estaActiva = opcion.accion == _seccionActiva;
          return PopupMenuItem<_AccionMenu>(
            value: opcion.accion,
            child: Row(
              children: [
                Icon(
                  opcion.icono,
                  size: 19,
                  color: estaActiva ? _rojoMarca : _grisTexto,
                ),
                const SizedBox(width: 12),
                Text(
                  opcion.etiqueta,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: estaActiva ? FontWeight.w700 : FontWeight.w500,
                    color: estaActiva ? _rojoMarca : _negroElegante,
                  ),
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        PopupMenuItem<_AccionMenu>(
          value: _AccionMenu.cerrarSesion,
          enabled: !_cerrandoSesion,
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 19,
                color: _cerrandoSesion ? _grisTexto : _rojoMarca,
              ),
              const SizedBox(width: 12),
              Text(
                _cerrandoSesion ? 'Cerrando sesión...' : 'Cerrar sesión',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _cerrandoSesion ? _grisTexto : _rojoMarca,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirEncabezadoBienvenida({required bool esEscritorio}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: esEscritorio ? 26 : 18,
            vertical: esEscritorio ? 22 : 18,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _bordeSuave),
            boxShadow: [
              BoxShadow(
                color: _rojoMarca.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _rosaSuave,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _bordeSuave),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: _rojoMarca,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido al Panel Administrativo',
                      style: TextStyle(
                        fontSize: esEscritorio ? 22 : 18,
                        fontWeight: FontWeight.w800,
                        color: _negroElegante,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Administra el catálogo, genera facturas y supervisa las ventas de Accesorios Ayala.',
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
        ),
      ),
    );
  }
}
