import 'package:flutter/material.dart';

import '../controllers/cliente_controller.dart';
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

  final TextEditingController _buscarCtrl = TextEditingController();

  List<Cliente> _clientes = [];
  bool _cargandoClientes = false;
  bool _errorClientes = false;
  bool _mostrarResultados = false;
  Cliente? _clienteSeleccionado;

  @override
  void initState() {
    super.initState();
    if (widget.clientes.isNotEmpty) {
      _clientes = List<Cliente>.from(widget.clientes);
    } else {
      _cargarClientes(desdeInitState: true);
    }
  }

  @override
  void didUpdateWidget(covariant NuevoPedidoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clientes.isNotEmpty) {
      _clientes = List<Cliente>.from(widget.clientes);
      _cargandoClientes = false;
      _errorClientes = false;
      _validarSeleccionActual();
    } else if (oldWidget.clientes.isNotEmpty && widget.clientes.isEmpty) {
      _cargarClientes();
    }
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  void _validarSeleccionActual() {
    if (_clienteSeleccionado != null &&
        !_clientes.any((c) => c.id == _clienteSeleccionado!.id)) {
      _clienteSeleccionado = null;
    }
  }

  Future<void> _cargarClientes({bool desdeInitState = false}) async {
    if (_cargandoClientes) return;

    if (desdeInitState) {
      _cargandoClientes = true;
      _errorClientes = false;
    } else {
      setState(() {
        _cargandoClientes = true;
        _errorClientes = false;
      });
    }

    try {
      final cargados = await ClienteController.cargarClientes();
      if (!mounted) return;

      setState(() {
        _clientes = cargados;
        _cargandoClientes = false;
        _errorClientes = false;
        _validarSeleccionActual();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cargandoClientes = false;
        _errorClientes = true;
      });
    }
  }

  String _normalizarTexto(String texto) {
    const mapaTildes = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
      'ç': 'c',
    };

    final minusculas = texto.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final codeUnit in minusculas.runes) {
      final char = String.fromCharCode(codeUnit);
      buffer.write(mapaTildes[char] ?? char);
    }
    return buffer.toString();
  }

  List<Cliente> _filtrarClientes() {
    final consulta = _normalizarTexto(_buscarCtrl.text);
    if (consulta.isEmpty) return _clientes;

    return _clientes
        .where((cliente) => _normalizarTexto(cliente.nombre).contains(consulta))
        .toList();
  }

  void _seleccionarCliente(Cliente cliente) {
    setState(() {
      _clienteSeleccionado = cliente;
      _mostrarResultados = false;
      _buscarCtrl.clear();
    });
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
    final clientesFiltrados = _filtrarClientes();

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
          if (_cargandoClientes)
            _construirEstadoCargando()
          else if (_errorClientes)
            _construirEstadoError()
          else if (_clientes.isEmpty)
            _construirSinClientes()
          else ...[
            _construirBuscadorClientes(),
            if (_mostrarResultados) ...[
              const SizedBox(height: 10),
              _construirResultadosClientes(clientesFiltrados),
            ],
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

  Widget _construirBuscadorClientes() {
    final tieneTexto = _buscarCtrl.text.isNotEmpty;

    return TextField(
      controller: _buscarCtrl,
      onTap: () {
        if (!_mostrarResultados) {
          setState(() {
            _mostrarResultados = true;
          });
        }
      },
      onChanged: (_) {
        setState(() {
          _mostrarResultados = true;
        });
      },
      decoration: InputDecoration(
        labelText: _clienteSeleccionado == null
            ? 'Buscar cliente por nombre'
            : 'Buscar otro cliente para cambiar',
        hintText: 'Escribe el nombre del cliente...',
        prefixIcon: const Icon(Icons.search_rounded, color: _rojoMarca),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tieneTexto)
              IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded, color: _grisTexto),
                onPressed: () {
                  setState(() {
                    _buscarCtrl.clear();
                    _mostrarResultados = true;
                  });
                },
              ),
            IconButton(
              tooltip: _mostrarResultados
                  ? 'Ocultar lista de clientes'
                  : 'Mostrar lista de clientes',
              icon: Icon(
                _mostrarResultados
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: _grisTexto,
              ),
              onPressed: () {
                setState(() {
                  _mostrarResultados = !_mostrarResultados;
                });
              },
            ),
          ],
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
    );
  }

  Widget _construirResultadosClientes(List<Cliente> clientesFiltrados) {
    if (clientesFiltrados.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _bordeSuave),
        ),
        child: const Text(
          'No se encontraron clientes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _grisTexto,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bordeSuave),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: clientesFiltrados.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: _bordeSuave),
        itemBuilder: (context, index) {
          final cliente = clientesFiltrados[index];
          final estaSeleccionado = _clienteSeleccionado?.id == cliente.id;
          final subtitulo = [
            if (cliente.telefono.trim().isNotEmpty) cliente.telefono.trim(),
            if (cliente.departamento.trim().isNotEmpty)
              cliente.departamento.trim(),
          ].join(' · ');

          return ListTile(
            dense: true,
            selected: estaSeleccionado,
            selectedTileColor: _rosaSuave.withValues(alpha: 0.7),
            leading: Icon(
              estaSeleccionado
                  ? Icons.check_circle_rounded
                  : Icons.person_outline_rounded,
              color: estaSeleccionado ? _rojoMarca : _grisTexto,
              size: 20,
            ),
            title: Text(
              cliente.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    estaSeleccionado ? FontWeight.w700 : FontWeight.w600,
                color: _negroElegante,
              ),
            ),
            subtitle: subtitulo.isNotEmpty
                ? Text(
                    subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: _grisTexto),
                  )
                : null,
            onTap: () => _seleccionarCliente(cliente),
          );
        },
      ),
    );
  }

  Widget _construirEstadoCargando() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _rojoMarca),
          SizedBox(height: 12),
          Text(
            'Cargando clientes...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _grisTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: _rosaSuave.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: _rojoMarca, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No se pudieron cargar los clientes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _cargarClientes,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
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
            child: Text(
              'No hay clientes registrados',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _negroElegante,
              ),
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
    final direccion = cliente.direccion.trim().isNotEmpty
        ? cliente.direccion.trim()
        : 'Sin dirección registrada';
    final departamento = cliente.departamento.trim();

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
          Row(
            children: [
              Expanded(
                child: Text(
                  cliente.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _negroElegante,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _mostrarResultados = true;
                  });
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Cambiar'),
                style: TextButton.styleFrom(
                  foregroundColor: _rojoMarca,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
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
                if (departamento.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DatoCliente(
                      icono: Icons.map_outlined,
                      etiqueta: 'Departamento',
                      valor: departamento,
                    ),
                  ),
                ],
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
            if (departamento.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DatoCliente(
                icono: Icons.map_outlined,
                etiqueta: 'Departamento',
                valor: departamento,
              ),
            ],
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
