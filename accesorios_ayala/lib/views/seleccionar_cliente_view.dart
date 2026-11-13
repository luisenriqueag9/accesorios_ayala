import 'package:flutter/material.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';

class SeleccionarClienteView extends StatefulWidget {
  final bool integrado;
  final ValueChanged<Cliente>? onClienteSeleccionado;

  const SeleccionarClienteView({
    super.key,
    this.integrado = false,
    this.onClienteSeleccionado,
  });

  @override
  State<SeleccionarClienteView> createState() => _SeleccionarClienteViewState();
}

class _SeleccionarClienteViewState extends State<SeleccionarClienteView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);
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
      final cargados = await ClienteController.cargarClientes();
      if (!mounted) return;
      clientes = cargados;
      clientesFiltrados = List.from(cargados);
    } catch (e) {
      if (!mounted) return;
      error = e.toString();
    } finally {
      if (mounted) {
        cargando = false;
        setState(() {});
      }
    }
  }

  void _seleccionarCliente(Cliente cliente) {
    if (widget.integrado) {
      widget.onClienteSeleccionado?.call(cliente);
    } else {
      Navigator.pop(context, cliente);
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

  Widget _construirBuscador({required EdgeInsetsGeometry padding}) {
    return Padding(
      padding: padding,
      child: TextField(
        controller: buscarCtrl,
        onChanged: filtrarClientes,
        decoration: InputDecoration(
          hintText: "Buscar cliente...",
          prefixIcon: Icon(
            Icons.search,
            color: widget.integrado ? _rojoMarca : null,
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: widget.integrado
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _bordeSuave),
                )
              : null,
          focusedBorder: widget.integrado
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _rojoMarca, width: 1.6),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.integrado ? 14 : 15),
          ),
        ),
      ),
    );
  }

  Widget _construirListaClientes({required bool shrinkWrap}) {
    if (clientesFiltrados.isEmpty) {
      final mensaje = const Center(
        child: Text(
          "No se encontraron clientes",
          style: TextStyle(color: _grisTexto),
        ),
      );
      if (shrinkWrap) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: mensaje,
        );
      }
      return mensaje;
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16),
      itemCount: clientesFiltrados.length,
      itemBuilder: (_, index) {
        final c = clientesFiltrados[index];

        return Card(
          elevation: widget.integrado ? 0 : 2,
          color: Colors.white,
          margin: EdgeInsets.only(bottom: widget.integrado ? 10 : 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.integrado ? 16 : 12),
            side: widget.integrado
                ? const BorderSide(color: _bordeSuave)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: widget.integrado
                  ? _rosaSuave
                  : Colors.red.shade100,
              foregroundColor: widget.integrado ? _rojoMarca : null,
              child: Text(
                c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : "?",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              c.nombre,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _negroElegante,
              ),
            ),
            subtitle: Text(
              "${c.telefono}\n${c.direccion}",
              style: widget.integrado
                  ? const TextStyle(color: _grisTexto)
                  : null,
            ),
            isThreeLine: true,
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: widget.integrado ? _rojoMarca : null,
            ),
            onTap: () => _seleccionarCliente(c),
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _bordeSuave),
              boxShadow: [
                BoxShadow(
                  color: _rojoMarca.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const Text(
                      "Seleccionar cliente",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _negroElegante,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _rosaSuave,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _bordeSuave),
                      ),
                      child: Text(
                        "${clientes.length} disponibles",
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _rojoMarca,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: _rojoMarca),
                    ),
                  )
                else if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "Error al cargar clientes:\n$error",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _grisTexto),
                      ),
                    ),
                  )
                else ...[
                  _construirBuscador(
                    padding: const EdgeInsets.only(bottom: 14),
                  ),
                  _construirListaClientes(shrinkWrap: true),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Seleccionar Cliente (${clientes.length})")),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Text(
                "Error al cargar clientes:\n$error",
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                _construirBuscador(padding: const EdgeInsets.all(16)),
                Expanded(child: _construirListaClientes(shrinkWrap: false)),
              ],
            ),
    );
  }
}
