import 'dart:ui';
import 'package:flutter/material.dart';
import '../controllers/cliente_controller.dart';
import '../models/cliente.dart';
import '../utils/widgets/glass_container.dart';
import 'registrar_cliente_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ListaClientesView extends StatefulWidget {
  const ListaClientesView({super.key});

  @override
  State<ListaClientesView> createState() => _ListaClientesViewState();
}

class _ListaClientesViewState extends State<ListaClientesView> {
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  String departamentoSeleccionado = "Todos";
  String busqueda = "";
  bool _eliminando = false;

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
    clientes = await ClienteController.cargarClientes();
    aplicarFiltro();
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
    final url = Uri.parse("https://wa.me/504$numero");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegistrarClienteView(),
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
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Buscar cliente...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (valor) {
                    busqueda = valor;
                    aplicarFiltro();
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
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
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegistrarClienteView(cliente: c),
                              ),
                            );
                            cargar();
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    abrirWhatsapp(c.telefono),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: _eliminando
                                    ? null
                                    : () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        final confirmar =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Eliminar cliente',
                                              ),
                                              content: Text(
                                                '¿Estás seguro de que deseas eliminar a "${c.nombre}"? Esta acción no se puede deshacer',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    dialogContext,
                                                    false,
                                                  ),
                                                  child: const Text(
                                                    'Cancelar',
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton
                                                      .styleFrom(
                                                    backgroundColor:
                                                        Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    dialogContext,
                                                    true,
                                                  ),
                                                  child: const Text(
                                                    'Sí, eliminar',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (confirmar != true ||
                                            !mounted ||
                                            _eliminando) {
                                          return;
                                        }

                                        setState(() => _eliminando = true);

                                        try {
                                          await ClienteController
                                              .eliminarCliente(c.id);
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
                                            setState(
                                              () => _eliminando = false,
                                            );
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
