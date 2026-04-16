import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/producto.dart';
import '../controllers/producto_controller.dart';
import '../utils/widgets/glass_container.dart';
import '../utils/widgets/mis_textfield.dart';
import '../utils/widgets/mis_button.dart';

class RegistrarProductoView extends StatefulWidget {
  final Producto? producto;

  const RegistrarProductoView({super.key, this.producto});

  @override
  State<RegistrarProductoView> createState() => _RegistrarProductoViewState();
}

class _RegistrarProductoViewState extends State<RegistrarProductoView> {
  final nombreCtrl = TextEditingController();
  final descripcionCtrl = TextEditingController();
  final precioCtrl = TextEditingController();

  Uint8List? imagenBytes;
  String? imagenPath;

  @override
  void initState() {
    super.initState();

    if (widget.producto != null) {
      nombreCtrl.text = widget.producto!.nombre;
      descripcionCtrl.text = widget.producto!.descripcion;
      precioCtrl.text = widget.producto!.precio.toString();

      if (kIsWeb && widget.producto!.imagenBase64 != null) {
        imagenBytes = widget.producto!.imagenBytes;
      }

      if (!kIsWeb && widget.producto!.imagenPath != null) {
        imagenPath = widget.producto!.imagenPath;
        _cargarImagenLocal(imagenPath!);
      }
    }
  }

  Future<void> _cargarImagenLocal(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      setState(() => imagenBytes = bytes);
    } catch (_) {}
  }

  Future<void> seleccionarImagen() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (kIsWeb) {
      setState(() => imagenBytes = bytes);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'producto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${dir.path}/$fileName';

      await File(filePath).writeAsBytes(bytes);

      setState(() {
        imagenPath = filePath;
        imagenBytes = bytes;
      });
    }
  }

  Future<void> guardar() async {
    if (nombreCtrl.text.isEmpty ||
        descripcionCtrl.text.isEmpty ||
        precioCtrl.text.isEmpty ||
        imagenBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    final precio = double.tryParse(precioCtrl.text);
    if (precio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Precio inválido")),
      );
      return;
    }

    final producto = Producto(
      id: widget.producto?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: nombreCtrl.text.trim(),
      descripcion: descripcionCtrl.text.trim(),
      precio: precio,
      imagenPath: kIsWeb ? null : imagenPath,
      imagenBase64: kIsWeb ? base64Encode(imagenBytes!) : null,
    );

    await ProductoController.guardarProducto(producto);
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    descripcionCtrl.dispose();
    precioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.producto == null
              ? "Registrar Producto"
              : "Editar Producto",
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
                  GestureDetector(
                    onTap: seleccionarImagen,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey.shade200,
                        image: imagenBytes != null
                            ? DecorationImage(
                                image: MemoryImage(imagenBytes!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imagenBytes == null
                          ? const Icon(Icons.image, size: 40)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  MisTextfield(
                    controller: nombreCtrl,
                    hintText: "Nombre",
                    obscureText: false,
                  ),
                  const SizedBox(height: 12),
                  MisTextfield(
                    controller: descripcionCtrl,
                    hintText: "Descripción",
                    obscureText: false,
                  ),
                  const SizedBox(height: 12),
                  MisTextfield(
                    controller: precioCtrl,
                    hintText: "Precio",
                    obscureText: false,
                  ),
                  const SizedBox(height: 25),
                  MisButtons(
                    text: widget.producto == null
                        ? "Guardar Producto"
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

/// ================= FONDOS =================

Widget _fondoDegradado() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFFE1F5FE),
          Color(0xFFCCF2F7),
          Colors.white,
        ],
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
