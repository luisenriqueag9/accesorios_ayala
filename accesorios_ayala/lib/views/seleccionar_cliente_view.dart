import 'dart:ui';
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
          prefixIcon: const Icon(Icons.search, color: _rojoMarca),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.88),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bordeSuave),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _rojoMarca, width: 1.6),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _construirListaClientes({required bool shrinkWrap}) {
    if (clientesFiltrados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(
            "No se encontraron clientes",
            style: TextStyle(color: _grisTexto),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: clientesFiltrados.length,
      itemBuilder: (_, index) {
        final c = clientesFiltrados[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.78),
                Colors.white.withValues(alpha: 0.58),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _rojoMarca.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _seleccionarCliente(c),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: _rosaSuave,
                  foregroundColor: _rojoMarca,
                  child: Text(
                    c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : "?",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  c.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
                subtitle: Text(
                  "${c.telefono}\n${c.direccion}",
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _grisTexto),
                ),
                isThreeLine: true,
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: _rojoMarca,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirPanelCristal({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.78),
                Colors.white.withValues(alpha: 0.56),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _bordeSuave, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: _rojoMarca.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _construirContenidoPrincipal({required bool mostrarTitulo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mostrarTitulo) ...[
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
          const SizedBox(height: 16),
        ],
        if (cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator(color: _rojoMarca)),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                "Error al cargar clientes:\n$error",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grisTexto),
              ),
            ),
          )
        else ...[
          _construirBuscador(padding: const EdgeInsets.only(bottom: 14)),
          _construirListaClientes(shrinkWrap: true),
        ],
      ],
    );
  }

  Widget _construirFondoIndependiente() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFF4F5), Color(0xFFFFE6E8)],
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _rojoMarca.withValues(alpha: 0.12),
                  _rojoMarca.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _rojoMarca.withValues(alpha: 0.10),
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
    if (widget.integrado) {
      return _construirPanelCristal(
        child: _construirContenidoPrincipal(mostrarTitulo: true),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.90),
        foregroundColor: _rojoMarca,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _rojoMarca),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _bordeSuave),
        ),
        title: Text(
          "Seleccionar Cliente (${clientes.length})",
          style: const TextStyle(
            color: _rojoMarca,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          _construirFondoIndependiente(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: _construirPanelCristal(
                    child: _construirContenidoPrincipal(mostrarTitulo: false),
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
