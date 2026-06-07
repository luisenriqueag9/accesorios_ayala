import 'dart:ui';
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
    productos = await ProductoController.cargarProductos();
    productosFiltrados = List.from(productos);
    setState(() {});
  }

  void filtrarProductos(String texto) {
    setState(() {
      productosFiltrados = productos.where((p) {
        return p.nombre.toLowerCase().contains(
              texto.toLowerCase(),
            );
      }).toList();
    });
  }

  Widget _imagenProducto(Producto p) {
    if (p.imageUrl == null || p.imageUrl!.isEmpty) {
      return const Icon(
        Icons.image,
        size: 40,
        color: Colors.grey,
      );
    }

    return SizedBox(
      width: 60,
      height: 60,
      child: Image.network(
        p.imageUrl!.trim(),
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          return const Icon(
            Icons.broken_image,
            color: Colors.red,
            size: 40,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Productos (${productos.length})",
        ),
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

          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: buscarCtrl,
                  onChanged: filtrarProductos,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: productosFiltrados.isEmpty
                    ? const Center(
                        child: Text(
                          "No se encontraron productos",
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.descripcion,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
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

                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RegistrarProductoView(
                                        producto: p,
                                      ),
                                    ),
                                  );

                                  cargar();
                                },

                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirmar =
                                        await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    20),
                                          ),
                                          title: const Text(
                                            'Eliminar producto',
                                          ),
                                          content: Text(
                                            '¿Seguro que deseas eliminar "${p.nombre}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(
                                                  context,
                                                  false,
                                                );
                                              },
                                              child:
                                                  const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              style:
                                                  ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red,
                                              ),
                                              onPressed: () {
                                                Navigator.pop(
                                                  context,
                                                  true,
                                                );
                                              },
                                              child: const Text(
                                                'Eliminar',
                                                style: TextStyle(
                                                  color:
                                                      Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirmar == true) {
                                      await ProductoController
                                          .eliminarProducto(
                                        p.id,
                                      );

                                      ScaffoldMessenger.of(
                                              context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${p.nombre} eliminado',
                                          ),
                                        ),
                                      );

                                      cargar();
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
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
    filter: ImageFilter.blur(
      sigmaX: 12,
      sigmaY: 12,
    ),
    child: Container(
      color: Colors.white10,
    ),
  );
}