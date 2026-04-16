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
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarClientes();
  }

  Future<void> cargarClientes() async {
    try {
      clientes = await ClienteController.cargarClientes();
    } catch (e) {
      error = e.toString();
    } finally {
      cargando = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Seleccionar Cliente")),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    "Error al cargar clientes:\n$error",
                    textAlign: TextAlign.center,
                  ),
                )
              : clientes.isEmpty
                  ? const Center(
                      child: Text("No hay clientes registrados"),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: clientes.length,
                      itemBuilder: (_, index) {
                        final c = clientes[index];

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(c.nombre),
                            subtitle:
                                Text("${c.telefono}\n${c.direccion}"),
                            isThreeLine: true,
                            onTap: () => Navigator.pop(context, c),
                          ),
                        );
                      },
                    ),
    );
  }
}
