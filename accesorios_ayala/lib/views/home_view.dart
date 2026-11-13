import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:accesorios_ayala/views/vista_previa_recibo_view.dart';

import '../controllers/auth_controller.dart';
import 'lista_clientes_view.dart';
import 'lista_productos_view.dart';
import 'seleccionar_cliente_view.dart';
import 'seleccionar_productos_view.dart';
import 'resumen_ventas_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _fondoClaro = Color(0xFFFAFAFA);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  bool _cerrandoSesion = false;

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

  Future<void> _abrirGenerarRecibo(BuildContext context) async {
    final cliente = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SeleccionarClienteView()),
    );

    if (cliente != null) {
      if (!context.mounted) return;
      final productosSeleccionados = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SeleccionarProductosView()),
      );

      if (productosSeleccionados != null) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VistaPreviaReciboView(
              cliente: cliente,
              seleccionados: productosSeleccionados,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _rojoMarca),
        shape: const Border(bottom: BorderSide(color: _bordeSuave, width: 1)),
        title: const Row(
          children: [
            Icon(Icons.diamond_outlined, color: _rojoMarca, size: 22),
            SizedBox(width: 10),
            Text(
              'Accesorios Ayala',
              style: TextStyle(
                color: _rojoMarca,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
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
                          _construirEncabezadoBienvenida(
                            esEscritorio: esEscritorio,
                          ),
                          const SizedBox(height: 28),

                          // Sección 1: Catálogo
                          _construirTituloSeccion(
                            titulo: 'Catálogo',
                            icono: Icons.storefront_outlined,
                          ),
                          const SizedBox(height: 12),
                          _construirGrupoTarjetas(
                            esEscritorio: esEscritorio,
                            tarjetas: [
                              _DashboardCard(
                                titulo: 'Gestión de Productos',
                                subtitulo:
                                    'Agrega, edita o elimina artículos y fotografías del catálogo.',
                                icono: Icons.shopping_bag_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ListaProductosView(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),

                          // Sección 2: Pedidos y Ventas
                          _construirTituloSeccion(
                            titulo: 'Pedidos y Ventas',
                            icono: Icons.point_of_sale_outlined,
                          ),
                          const SizedBox(height: 12),
                          _construirGrupoTarjetas(
                            esEscritorio: esEscritorio,
                            tarjetas: [
                              _DashboardCard(
                                titulo: 'Generar Recibo',
                                subtitulo:
                                    'Selecciona cliente y productos para emitir un comprobante PDF.',
                                icono: Icons.receipt_long_outlined,
                                onTap: () => _abrirGenerarRecibo(context),
                              ),
                              _DashboardCard(
                                titulo: 'Ventas',
                                subtitulo:
                                    'Consulta el resumen diario, mensual y el historial de ventas.',
                                icono: Icons.bar_chart_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ResumenVentasView(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),

                          // Sección 3: Administración
                          _construirTituloSeccion(
                            titulo: 'Administración',
                            icono: Icons.admin_panel_settings_outlined,
                          ),
                          const SizedBox(height: 12),
                          _construirGrupoTarjetas(
                            esEscritorio: esEscritorio,
                            tarjetas: [
                              _DashboardCard(
                                titulo: 'Gestión de Clientes',
                                subtitulo:
                                    'Administra datos de contacto, departamentos y WhatsApp.',
                                icono: Icons.people_outline_rounded,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ListaClientesView(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                      'Administra el catálogo, genera recibos y supervisa las ventas de Accesorios Ayala.',
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

  Widget _construirTituloSeccion({
    required String titulo,
    required IconData icono,
  }) {
    return Row(
      children: [
        Icon(icono, size: 19, color: _rojoMarca),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: _negroElegante,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _construirGrupoTarjetas({
    required bool esEscritorio,
    required List<Widget> tarjetas,
  }) {
    if (!esEscritorio || tarjetas.length == 1) {
      return Column(
        children: [
          for (int i = 0; i < tarjetas.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            tarjetas[i],
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const separacion = 16.0;
        final anchoTarjeta = (constraints.maxWidth - separacion) / 2;
        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: tarjetas
              .map((tarjeta) => SizedBox(width: anchoTarjeta, child: tarjeta))
              .toList(),
        );
      },
    );
  }
}

class _DashboardCard extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.onTap,
  });

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _hover
                  ? _rojoMarca.withValues(alpha: 0.10)
                  : _negroElegante.withValues(alpha: 0.04),
              blurRadius: _hover ? 20 : 12,
              offset: Offset(0, _hover ? 8 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.white.withValues(alpha: _hover ? 0.92 : 0.80),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _hover
                          ? _rojoMarca.withValues(alpha: 0.35)
                          : _bordeSuave,
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _rosaSuave,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _bordeSuave),
                        ),
                        child: Icon(widget.icono, color: _rojoMarca, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.titulo,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _negroElegante,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _grisTexto,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _hover ? _rojoMarca : _grisTexto,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
