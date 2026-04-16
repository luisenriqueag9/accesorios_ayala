import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/producto_controller.dart';
import '../models/producto.dart';
import '../utils/widgets/glass_container.dart';
import 'registrar_producto_view.dart';

class ListaProductosView extends StatefulWidget {
  const ListaProductosView({super.key});

  @override
  State<ListaProductosView> createState() => _ListaProductosViewState();
}

class _ListaProductosViewState extends State<ListaProductosView> {
  List<Producto> productos = [];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    productos = await ProductoController.cargarProductos();
    setState(() {});
  }

  Widget _imagenProducto(Producto p) {
    if (kIsWeb && p.tieneImagenBase64) {
      return Image.memory(
        p.imagenBytes!,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      );
    }

    if (!kIsWeb && p.tieneImagenLocal) {
      return Image.file(
        File(p.imagenPath!),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      );
    }

    return const Icon(Icons.image, size: 40);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Productos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegistrarProductoView(),
                ),
              );
              cargar();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _fondoDegradado(),
          _fondoBlur(),
          productos.isEmpty
              ? const Center(
                  child: Text(
                    "No hay productos registrados",
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: productos.length,
                  itemBuilder: (_, index) {
                    final p = productos[index];

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
                          subtitle: Text(
                            "L. ${p.precio.toStringAsFixed(2)}",
                            style:
                                const TextStyle(color: Colors.black54),
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegistrarProductoView(producto: p),
                              ),
                            );
                            cargar();
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await ProductoController.eliminarProducto(p.id);
                              cargar();
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

/// FONDOS
Widget _fondoDegradado() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFFE1F5FE),
          Color(0xFFCCF2F7),
          Colors.white,
        ],
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
