import 'package:flutter/material.dart';

import '../models/cliente.dart';

class NuevoPedidoView extends StatefulWidget {
  final List<Cliente> clientes;

  const NuevoPedidoView({
    super.key,
    this.clientes = const [],
  });

  @override
  State<NuevoPedidoView> createState() => _NuevoPedidoViewState();
}

class _NuevoPedidoViewState extends State<NuevoPedidoView> {
  static const double _breakpointEscritorio = 760;
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  Cliente? _clienteSeleccionado;

  @override
  void didUpdateWidget(covariant NuevoPedidoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_clienteSeleccionado != null &&
        !widget.clientes.any((c) => c.id == _clienteSeleccionado!.id)) {
      _clienteSeleccionado = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esEscritorio = constraints.maxWidth >= _breakpointEscritorio;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _construirEncabezado(esEscritorio: esEscritorio),
            const SizedBox(height: 16),
            _construirSeccionCliente(esEscritorio: esEscritorio),
          ],
        );
      },
    );
  }

  Widget _construirEncabezado({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: esEscritorio ? 28 : 20,
        vertical: esEscritorio ? 22 : 18,
      ),
      decoration: _decoracionTarjeta(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _rosaSuave,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _bordeSuave),
            ),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: _rojoMarca,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nuevo pedido',
                  style: TextStyle(
                    fontSize: esEscritorio ? 22 : 19,
                    fontWeight: FontWeight.w800,
                    color: _negroElegante,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecciona un cliente existente para iniciar el pedido.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _grisTexto,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionCliente({required bool esEscritorio}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esEscritorio ? 24 : 18),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline_rounded, color: _rojoMarca, size: 22),
              SizedBox(width: 8),
              Text(
                'Cliente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _negroElegante,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.clientes.isEmpty)
            _construirSinClientes()
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _clienteSeleccionado?.id,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Seleccionar cliente existente',
                prefixIcon: const Icon(
                  Icons.people_outline_rounded,
                  color: _rojoMarca,
                ),
                filled: true,
                fillColor: _rosaSuave.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _bordeSuave),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _bordeSuave),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _rojoMarca, width: 1.5),
                ),
              ),
              items: widget.clientes
                  .map(
                    (cliente) => DropdownMenuItem<String>(
                      value: cliente.id,
                      child: Text(
                        cliente.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (idSeleccionado) {
                if (idSeleccionado == null) return;
                final encontrado = widget.clientes.firstWhere(
                  (c) => c.id == idSeleccionado,
                );
                setState(() {
                  _clienteSeleccionado = encontrado;
                });
              },
            ),
            if (_clienteSeleccionado != null) ...[
              const SizedBox(height: 16),
              _construirDetalleClienteSeleccionado(
                _clienteSeleccionado!,
                esEscritorio: esEscritorio,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _construirSinClientes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _rojoMarca, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Todavía no se han cargado clientes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cuando se conecte la carga de clientes, aquí podrás seleccionar un cliente existente para el pedido.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _grisTexto,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirDetalleClienteSeleccionado(
    Cliente cliente, {
    required bool esEscritorio,
  }) {
    final telefono = cliente.telefono.trim().isNotEmpty
        ? cliente.telefono.trim()
        : 'Sin teléfono registrado';
    final direccionBase = cliente.direccion.trim();
    final departamento = cliente.departamento.trim();
    final direccion = direccionBase.isNotEmpty
        ? (departamento.isNotEmpty
              ? '$direccionBase, $departamento'
              : direccionBase)
        : (departamento.isNotEmpty ? departamento : 'Sin dirección registrada');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cliente.nombre,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 10),
          if (esEscritorio)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DatoCliente(
                    icono: Icons.phone_outlined,
                    etiqueta: 'Teléfono',
                    valor: telefono,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _DatoCliente(
                    icono: Icons.location_on_outlined,
                    etiqueta: 'Dirección',
                    valor: direccion,
                  ),
                ),
              ],
            )
          else ...[
            _DatoCliente(
              icono: Icons.phone_outlined,
              etiqueta: 'Teléfono',
              valor: telefono,
            ),
            const SizedBox(height: 8),
            _DatoCliente(
              icono: Icons.location_on_outlined,
              etiqueta: 'Dirección',
              valor: direccion,
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _decoracionTarjeta() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _bordeSuave),
      boxShadow: [
        BoxShadow(
          color: _rojoMarca.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _DatoCliente extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _DatoCliente({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 17, color: const Color(0xFFD9232E)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6E6566),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202020),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
