import 'dart:ui';
import 'package:flutter/material.dart';

import '../controllers/producto_controller.dart';
import '../models/producto.dart';
import '../utils/widgets/glass_container.dart';
import 'registrar_producto_view.dart';

class ListaProductosView extends StatefulWidget {
  final bool integrado;

  const ListaProductosView({super.key, this.integrado = false});

  @override
  State<ListaProductosView> createState() => _ListaProductosViewState();
}

class _ListaProductosViewState extends State<ListaProductosView> {
  List<Producto> productos = [];
  List<Producto> productosFiltrados = [];

  final buscarCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargar();
  }

  @override
  void dispose() {
    buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> cargar() async {
    final cargados = await ProductoController.cargarProductos();
    if (!mounted) return;
    productos = cargados;
    productosFiltrados = List.from(productos);
    setState(() {});
  }

  Future<void> _abrirRegistroProducto([Producto? producto]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrarProductoView(producto: producto),
      ),
    );
    if (!mounted) return;
    cargar();
  }

  void filtrarProductos(String texto) {
    setState(() {
      productosFiltrados = productos.where((p) {
        return p.nombre.toLowerCase().contains(texto.toLowerCase());
      }).toList();
    });
  }

  Widget _imagenProducto(Producto p) {
    if (p.imageUrl == null || p.imageUrl!.isEmpty) {
      return const Icon(Icons.image, size: 40, color: Colors.grey);
    }

    return SizedBox(
      width: 60,
      height: 60,
      child: Image.network(
        p.imageUrl!.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          return const Icon(Icons.broken_image, color: Colors.red, size: 40);
        },
      ),
    );
  }

  Widget _construirBuscador({required EdgeInsetsGeometry padding}) {
    return Padding(
      padding: padding,
      child: TextField(
        controller: buscarCtrl,
        onChanged: filtrarProductos,
        decoration: InputDecoration(
          hintText: 'Buscar producto...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _construirListaProductos({required bool shrinkWrap}) {
    if (productosFiltrados.isEmpty) {
      final mensajeVacio = const Center(
        child: Text(
          "No se encontraron productos",
          style: TextStyle(fontSize: 18),
        ),
      );

      if (shrinkWrap) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: mensajeVacio,
        );
      }

      return mensajeVacio;
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(16),
      itemCount: productosFiltrados.length,
      itemBuilder: (_, index) {
        final p = productosFiltrados[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassContainer(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _imagenProducto(p),
              ),
              title: Text(
                p.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.descripcion,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    "L. ${p.precio.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              onTap: () => _abrirRegistroProducto(p),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Eliminar producto'),
                        content: Text(
                          '¿Seguro que deseas eliminar "${p.nombre}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext, false);
                            },
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () {
                              Navigator.pop(dialogContext, true);
                            },
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmar == true) {
                    await ProductoController.eliminarProducto(p.id);
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${p.nombre} eliminado')),
                    );

                    cargar();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.integrado) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                "Productos (${productos.length})",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202020),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _abrirRegistroProducto(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD9232E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar producto'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _construirBuscador(padding: const EdgeInsets.only(bottom: 8)),
          _construirListaProductos(shrinkWrap: true),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Productos (${productos.length})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _abrirRegistroProducto(),
          ),
        ],
      ),
      body: Stack(
        children: [
          _fondoDegradado(),
          _fondoBlur(),
          Column(
            children: [
              _construirBuscador(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              ),
              Expanded(child: _construirListaProductos(shrinkWrap: false)),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _fondoDegradado() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFE1F5FE), Color(0xFFCCF2F7), Colors.white],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  );
}

Widget _fondoBlur() {
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: Container(color: Colors.white10),
  );
}
