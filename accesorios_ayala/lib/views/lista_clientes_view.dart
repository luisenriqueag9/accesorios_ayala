import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';
import '../utils/widgets/glass_container.dart';
import 'registrar_cliente_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ListaClientesView extends StatefulWidget {
  final bool integrado;

  const ListaClientesView({super.key, this.integrado = false});

  @override
  State<ListaClientesView> createState() => _ListaClientesViewState();
}

class _ListaClientesViewState extends State<ListaClientesView> {
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  String departamentoSeleccionado = "Todos";
  String busqueda = "";
  bool _eliminando = false;
  bool _mostrandoFormulario = false;
  Cliente? _clienteEnEdicion;

  final List<String> departamentos = [
    "Todos",
    "Atlántida",
    "Choluteca",
    "Colón",
    "Comayagua",
    "Copán",
    "Cortés",
    "El Paraíso",
    "Francisco Morazán",
    "Gracias a Dios",
    "Intibucá",
    "Islas de la Bahía",
    "La Paz",
    "Lempira",
    "Ocotepeque",
    "Olancho",
    "Santa Bárbara",
    "Valle",
    "Yoro",
  ];

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final cargados = await ClienteController.cargarClientes();
    if (!mounted) return;
    clientes = cargados;
    aplicarFiltro();
  }

  Future<void> _abrirRegistrarCliente([Cliente? cliente]) async {
    if (widget.integrado) {
      setState(() {
        _clienteEnEdicion = cliente;
        _mostrandoFormulario = true;
      });
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegistrarClienteView(cliente: cliente)),
    );
    if (!mounted) return;
    cargar();
  }

  void aplicarFiltro() {
    List<Cliente> temp = List.from(clientes);

    if (departamentoSeleccionado != "Todos") {
      temp = temp
          .where((c) => c.departamento == departamentoSeleccionado)
          .toList();
    }

    if (busqueda.isNotEmpty) {
      temp = temp
          .where((c) => c.nombre.toLowerCase().contains(busqueda.toLowerCase()))
          .toList();
    }

    clientesFiltrados = temp;
    setState(() {});
  }

  void abrirFiltro() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              "Filtrar por departamento",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: departamentos.length,
                itemBuilder: (_, index) {
                  final d = departamentos[index];
                  return ListTile(
                    title: Text(d),
                    trailing: d == departamentoSeleccionado
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      departamentoSeleccionado = d;
                      aplicarFiltro();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> abrirWhatsapp(String numero) async {
    final texto = numero.trim();
    final limpio = texto.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    String? telefonoWa;

    if (limpio.startsWith('+')) {
      final digitos = limpio.substring(1);
      if (RegExp(r'^[1-9]\d{7,14}$').hasMatch(digitos)) {
        telefonoWa = digitos;
      }
    } else if (RegExp(r'^\d{8}$').hasMatch(limpio)) {
      telefonoWa = '504$limpio';
    }

    if (telefonoWa == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Número de teléfono ambiguo o no válido para abrir en WhatsApp.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse("https://wa.me/$telefonoWa");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _construirBuscador({required EdgeInsetsGeometry padding}) {
    return Padding(
      padding: padding,
      child: TextField(
        decoration: InputDecoration(
          hintText: "Buscar cliente...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: widget.integrado
              ? Colors.white
              : Colors.white.withValues(alpha: 0.8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (valor) {
          busqueda = valor;
          aplicarFiltro();
        },
      ),
    );
  }

  Widget _construirListaClientes({required bool shrinkWrap}) {
    if (clientesFiltrados.isEmpty) {
      final mensajeVacio = const Center(
        child: Text(
          "No se encontraron clientes",
          style: TextStyle(fontSize: 16),
        ),
      );

      if (shrinkWrap) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: mensajeVacio,
        );
      }

      return mensajeVacio;
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: shrinkWrap
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.all(16),
      itemCount: clientesFiltrados.length,
      itemBuilder: (_, index) {
        final c = clientesFiltrados[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            child: ListTile(
              title: Text(
                c.nombre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                "${c.telefono}\n${c.direccion}\n${c.departamento}",
              ),
              isThreeLine: true,
              onTap: () => _abrirRegistrarCliente(c),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Colors.green,
                    ),
                    onPressed: () => abrirWhatsapp(c.telefono),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _eliminando
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final confirmar = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text('Eliminar cliente'),
                                  content: Text(
                                    '¿Estás seguro de que deseas eliminar a "${c.nombre}"? Esta acción no se puede deshacer',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text(
                                        'Sí, eliminar',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmar != true || !mounted || _eliminando) {
                              return;
                            }

                            setState(() => _eliminando = true);

                            try {
                              await ClienteController.eliminarCliente(c.id);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Cliente "${c.nombre}" eliminado correctamente',
                                  ),
                                ),
                              );
                            } catch (_) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo eliminar el cliente. Intenta nuevamente.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            } finally {
                              if (mounted) {
                                setState(() => _eliminando = false);
                              }
                            }

                            if (mounted) await cargar();
                          },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.integrado) {
      if (_mostrandoFormulario) {
        return RegistrarClienteView(
          key: ValueKey(_clienteEnEdicion?.id ?? 'nuevo_cliente'),
          cliente: _clienteEnEdicion,
          integrado: true,
          onCancelar: () {
            setState(() {
              _mostrandoFormulario = false;
              _clienteEnEdicion = null;
            });
          },
          onGuardado: () {
            setState(() {
              _mostrandoFormulario = false;
              _clienteEnEdicion = null;
            });
            cargar();
          },
        );
      }

      final hayFiltroDepartamento = departamentoSeleccionado != "Todos";

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                "Clientes (${clientes.length})",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202020),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: abrirFiltro,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hayFiltroDepartamento
                          ? const Color(0xFFD9232E)
                          : const Color(0xFF6E6566),
                      backgroundColor: hayFiltroDepartamento
                          ? const Color(0xFFFFF1F2)
                          : Colors.white,
                      side: const BorderSide(color: Color(0xFFF0DDE0)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.filter_list, size: 18),
                    label: Text(
                      hayFiltroDepartamento
                          ? 'Filtrar: $departamentoSeleccionado'
                          : 'Filtrar',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _abrirRegistrarCliente(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD9232E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Agregar cliente'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _construirBuscador(padding: const EdgeInsets.only(bottom: 8)),
          _construirListaClientes(shrinkWrap: true),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: abrirFiltro,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _abrirRegistrarCliente(),
          ),
        ],
      ),
      body: Stack(
        children: [
          _fondoDegradado(),
          _fondoBlur(),
          Column(
            children: [
              _construirBuscador(padding: const EdgeInsets.all(12)),
              Expanded(child: _construirListaClientes(shrinkWrap: false)),
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
        colors: [Color(0xFFE1F5FE), Color(0xFFCCF2F7), Colors.white],
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
