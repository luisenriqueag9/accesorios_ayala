import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/producto_controller.dart';
import '../models/producto.dart';

class SeleccionarProductosView extends StatefulWidget {
  final bool integrado;
  final ValueChanged<List<Map<String, dynamic>>>? onContinuar;
  final VoidCallback? onVolver;
  final List<Map<String, dynamic>>? seleccionInicial;

  const SeleccionarProductosView({
    super.key,
    this.integrado = false,
    this.onContinuar,
    this.onVolver,
    this.seleccionInicial,
  });

  @override
  State<SeleccionarProductosView> createState() =>
      _SeleccionarProductosViewState();
}

class _SeleccionarProductosViewState extends State<SeleccionarProductosView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  List<Producto> productos = [];
  Map<int, int> cantidades = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    cargarProductos();
  }

  Future<void> cargarProductos() async {
    final cargados = await ProductoController.cargarProductos();
    if (!mounted) return;

    final cantidadesRestauradas = <int, int>{};
    final inicial = widget.seleccionInicial;
    if (inicial != null && inicial.isNotEmpty) {
      final cantidadesPorId = <String, int>{};
      for (final item in inicial) {
        final prod = item['producto'];
        final cant = item['cantidad'];
        if (prod is Producto && cant is int && cant > 0) {
          cantidadesPorId[prod.id] = cant;
        }
      }

      for (int i = 0; i < cargados.length; i++) {
        final cant = cantidadesPorId[cargados[i].id];
        if (cant != null && cant > 0) {
          cantidadesRestauradas[i] = cant;
        }
      }
    }

    setState(() {
      productos = cargados;
      cantidades = cantidadesRestauradas;
      _cargando = false;
    });
  }

  void finalizarSeleccion() {
    final seleccionados = <Map<String, dynamic>>[];

    cantidades.forEach((index, cantidad) {
      if (cantidad > 0 && index >= 0 && index < productos.length) {
        seleccionados.add({"producto": productos[index], "cantidad": cantidad});
      }
    });

    if (widget.integrado) {
      widget.onContinuar?.call(seleccionados);
    } else {
      Navigator.pop(context, seleccionados);
    }
  }

  void _actualizarCantidad(int index, int delta) {
    setState(() {
      final current = cantidades[index] ?? 0;
      final next = current + delta;
      cantidades[index] = next < 0 ? 0 : next;
    });
  }

  Widget _construirTarjetaProducto(int index, Producto p) {
    final cantidad = cantidades[index] ?? 0;
    final seleccionado = cantidad > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: seleccionado ? 0.68 : 0.56),
            Colors.white.withValues(alpha: seleccionado ? 0.44 : 0.34),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seleccionado
              ? _rojoMarca.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.85),
          width: seleccionado ? 1.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _rojoMarca.withValues(alpha: seleccionado ? 0.09 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _actualizarCantidad(index, 1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: p.imageUrl != null && p.imageUrl!.trim().isNotEmpty
                      ? Image.network(
                          p.imageUrl!.trim(),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _iconoPlaceholder(),
                        )
                      : _iconoPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _negroElegante,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "L. ${p.precio.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _grisTexto,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _rosaSuave.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _bordeSuave),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_rounded, size: 18),
                          color: cantidad > 0 ? _rojoMarca : _grisTexto,
                          tooltip: 'Disminuir',
                          onPressed: () => _actualizarCantidad(index, -1),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 24),
                          child: Text(
                            "$cantidad",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: seleccionado ? _rojoMarca : _negroElegante,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          color: _rojoMarca,
                          tooltip: 'Aumentar',
                          onPressed: () => _actualizarCantidad(index, 1),
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

  Widget _iconoPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: _rosaSuave,
      child: const Icon(Icons.image_outlined, size: 28, color: _rojoMarca),
    );
  }

  Widget _construirLista({required bool shrinkWrap}) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: _rojoMarca)),
      );
    }

    if (productos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            "No hay productos disponibles",
            style: TextStyle(color: _grisTexto),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap ? EdgeInsets.zero : const EdgeInsets.all(16),
      itemCount: productos.length,
      itemBuilder: (_, index) =>
          _construirTarjetaProducto(index, productos[index]),
    );
  }

  Widget _construirPanelCristal({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _rojoMarca.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.52),
                  Colors.white.withValues(alpha: 0.30),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.4,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _construirEncabezadoIntegrado(int totalUnidades) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            const Text(
              "Seleccionar productos",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _negroElegante,
              ),
            ),
            if (totalUnidades > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _rosaSuave.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _bordeSuave),
                ),
                child: Text(
                  "$totalUnidades unidades",
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _rojoMarca,
                  ),
                ),
              ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => widget.onVolver?.call(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _grisTexto,
                backgroundColor: Colors.white.withValues(alpha: 0.75),
                side: const BorderSide(color: _bordeSuave),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver a Cliente'),
            ),
            ElevatedButton.icon(
              onPressed: finalizarSeleccion,
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
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Continuar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _construirFondoIndependiente() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFEDF0), Color(0xFFFFDCE2)],
              stops: [0.0, 0.52, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _rojoMarca.withValues(alpha: 0.20),
                  _rojoMarca.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -70,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _rojoMarca.withValues(alpha: 0.16),
                  _rojoMarca.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnidades = cantidades.values.fold<int>(0, (a, b) => a + b);

    if (widget.integrado) {
      return _construirPanelCristal(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirEncabezadoIntegrado(totalUnidades),
            const SizedBox(height: 16),
            _construirLista(shrinkWrap: true),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _rosaSuave,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.90),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _rojoMarca),
        shape: const Border(bottom: BorderSide(color: _bordeSuave, width: 1)),
        title: const Text(
          "Seleccionar Productos",
          style: TextStyle(
            color: _rojoMarca,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: _rojoMarca),
            tooltip: 'Continuar',
            onPressed: finalizarSeleccion,
          ),
        ],
      ),
      body: Stack(
        children: [
          _construirFondoIndependiente(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: _construirPanelCristal(
                    child: _construirLista(shrinkWrap: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
