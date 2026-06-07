import 'package:flutter/material.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

class SeleccionarClienteView extends StatefulWidget {
  const SeleccionarClienteView({super.key});

  @override
  State<SeleccionarClienteView> createState() =>
      _SeleccionarClienteViewState();
}

class _SeleccionarClienteViewState extends State<SeleccionarClienteView> {
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];

  bool cargando = true;
  String? error;

  final buscarCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargarClientes();
  }

  @override
  void dispose() {
    buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> cargarClientes() async {
    try {
      clientes = await ClienteController.cargarClientes();
      clientesFiltrados = List.from(clientes);
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      setState(() {});
    }
  }

  void filtrarClientes(String texto) {
    setState(() {
      clientesFiltrados = clientes.where((c) {
        return c.nombre.toLowerCase().contains(texto.toLowerCase()) ||
            c.telefono.toLowerCase().contains(texto.toLowerCase()) ||
            c.direccion.toLowerCase().contains(texto.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Seleccionar Cliente (${clientes.length})",
        ),
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error != null
              ? Center(
                  child: Text(
                    "Error al cargar clientes:\n$error",
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: buscarCtrl,
                        onChanged: filtrarClientes,
                        decoration: InputDecoration(
                          hintText: "Buscar cliente...",
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
                      child: clientesFiltrados.isEmpty
                          ? const Center(
                              child: Text(
                                "No se encontraron clientes",
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: clientesFiltrados.length,
                              itemBuilder: (_, index) {
                                final c = clientesFiltrados[index];

                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Colors.red.shade100,
                                      child: Text(
                                        c.nombre.isNotEmpty
                                            ? c.nombre[0].toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      c.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${c.telefono}\n${c.direccion}",
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () =>
                                        Navigator.pop(context, c),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}