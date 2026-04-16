import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../controllers/cliente_controller.dart';
import '../utils/widgets/glass_container.dart';
import '../utils/widgets/mis_textfield.dart';
import '../utils/widgets/mis_button.dart';

class RegistrarClienteView extends StatefulWidget {
  final Cliente? cliente;

  const RegistrarClienteView({super.key, this.cliente});

  @override
  State<RegistrarClienteView> createState() => _RegistrarClienteViewState();
}

class _RegistrarClienteViewState extends State<RegistrarClienteView> {
  final nombreCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();

  String departamentoSeleccionado = "Cortés";

  final List<String> departamentos = [
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

    if (widget.cliente != null) {
      nombreCtrl.text = widget.cliente!.nombre;
      telefonoCtrl.text = widget.cliente!.telefono;
      direccionCtrl.text = widget.cliente!.direccion;
      departamentoSeleccionado = widget.cliente!.departamento;
    }
  }

  Future<void> guardar() async {
    if (nombreCtrl.text.isEmpty ||
        telefonoCtrl.text.isEmpty ||
        direccionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    final cliente = Cliente(
      id: widget.cliente?.id ?? "",
      nombre: nombreCtrl.text.trim(),
      telefono: telefonoCtrl.text.trim(),
      direccion: direccionCtrl.text.trim(),
      departamento: departamentoSeleccionado,
    );

    if (widget.cliente == null) {
      await ClienteController.agregarCliente(cliente);
    } else {
      await ClienteController.editarCliente(cliente);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.cliente == null
              ? "Cliente agregado correctamente"
              : "Cliente actualizado",
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.cliente == null ? "Registrar Cliente" : "Editar Cliente",
        ),
      ),
      body: Stack(
        children: [
          _fondoDegradado(),
          _fondoBlur(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: GlassContainer(
              child: Column(
                children: [
                  MisTextfield(
                    controller: nombreCtrl,
                    hintText: "Nombre",
                    obscureText: false,
                  ),
                  MisTextfield(
                    controller: telefonoCtrl,
                    hintText: "Teléfono",
                    obscureText: false,
                  ),
                  MisTextfield(
                    controller: direccionCtrl,
                    hintText: "Dirección",
                    obscureText: false,
                  ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: departamentoSeleccionado,
                    items: departamentos
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d),
                          ),
                        )
                        .toList(),
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => departamentoSeleccionado = valor);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Departamento",
                    ),
                  ),

                  const SizedBox(height: 25),

                  MisButtons(
                    text: widget.cliente == null
                        ? "Guardar Cliente"
                        : "Guardar Cambios",
                    onTap: guardar,
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
