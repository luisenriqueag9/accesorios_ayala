import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:accesorios_ayala/views/vista_previa_recibo_view.dart';

import '../utils/theme.dart';
import 'lista_clientes_view.dart';
import 'lista_productos_view.dart';
import 'seleccionar_cliente_view.dart';
import 'seleccionar_productos_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Accesorios Ayala")),
      body: Stack(
        children: [
          // Fondo degradado
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE1F5FE),
                  Color(0xFFCCF2F7),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),

          // Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.white10),
          ),

          // Contenido
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bienvenido",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textoOscuro,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // CLIENTES
                  _buildGlassCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ListaClientesView(),
                        ),
                      );
                    },
                    child: const ListTile(
                      leading: Icon(Icons.people, size: 33),
                      title: Text("Gestión de Clientes"),
                      trailing: Icon(Icons.chevron_right),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // PRODUCTOS
                  _buildGlassCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ListaProductosView(),
                        ),
                      );
                    },
                    child: const ListTile(
                      leading: Icon(Icons.shopping_bag, size: 33),
                      title: Text("Gestión de Productos"),
                      trailing: Icon(Icons.chevron_right),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // GENERAR RECIBO
                  _buildGlassCard(
                    onTap: () async {
                      final cliente = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SeleccionarClienteView(),
                        ),
                      );

                      if (cliente != null) {
                        final productosSeleccionados = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SeleccionarProductosView(),
                          ),
                        );

                        if (productosSeleccionados != null) {
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
                    },
                    child: const ListTile(
                      leading: Icon(Icons.receipt_long, size: 33),
                      title: Text("Generar Recibo"),
                      trailing: Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildGlassCard({required Widget child, required VoidCallback? onTap}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: child,
        ),
      ),
    ),
  );
}
