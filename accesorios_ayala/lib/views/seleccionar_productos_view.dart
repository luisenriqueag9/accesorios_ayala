import 'package:flutter/material.dart';
import '../controllers/producto_controller.dart';
import '../models/producto.dart';

class SeleccionarProductosView extends StatefulWidget {
  const SeleccionarProductosView({super.key});

  @override
  State<SeleccionarProductosView> createState() =>
      _SeleccionarProductosViewState();
}

class _SeleccionarProductosViewState extends State<SeleccionarProductosView> {
  List<Producto> productos = [];
  Map<int, int> cantidades = {};

  @override
  void initState() {
    super.initState();
    cargarProductos();
  }

  Future<void> cargarProductos() async {
    productos = await ProductoController.cargarProductos();
    setState(() {});
  }

  void finalizarSeleccion() {
    final seleccionados = <Map<String, dynamic>>[];

    cantidades.forEach((index, cantidad) {
      if (cantidad > 0) {
        seleccionados.add({"producto": productos[index], "cantidad": cantidad});
      }
    });

    Navigator.pop(context, seleccionados);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Seleccionar Productos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: finalizarSeleccion,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: productos.length,
        itemBuilder: (_, index) {
          final p = productos[index];

          return Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: p.imagenBytes != null
                    ? Image.memory(
                        p.imagenBytes!,
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image, size: 40),
              ),

              title: Text(p.nombre),
              subtitle: Text("L. ${p.precio.toStringAsFixed(2)}"),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        final current = cantidades[index] ?? 0;
                        if (current > 0) {
                          cantidades[index] = current - 1;
                        }
                      });
                    },
                  ),

                  Text(
                    "${cantidades[index] ?? 0}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setState(() {
                        final current = cantidades[index] ?? 0;
                        cantidades[index] = current + 1;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
