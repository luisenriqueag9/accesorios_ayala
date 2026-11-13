import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/producto.dart';
import '../controllers/producto_controller.dart';

class RegistrarProductoView extends StatefulWidget {
  final Producto? producto;
  final bool integrado;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const RegistrarProductoView({
    super.key,
    this.producto,
    this.integrado = false,
    this.onGuardado,
    this.onCancelar,
  });

  @override
  State<RegistrarProductoView> createState() => _RegistrarProductoViewState();
}

class _RegistrarProductoViewState extends State<RegistrarProductoView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _fondoClaro = Color(0xFFFAFAFA);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  final nombreCtrl = TextEditingController();
  final descripcionCtrl = TextEditingController();
  final precioCtrl = TextEditingController();

  Uint8List? imagenBytes;
  bool _guardando = false;

  Future<String?> subirImagenStorage(Uint8List bytes) async {
    try {
      final fileName = 'productos/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance.ref().child(fileName);

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();

      return url;
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();

    if (widget.producto != null) {
      nombreCtrl.text = widget.producto!.nombre;
      descripcionCtrl.text = widget.producto!.descripcion;
      precioCtrl.text = widget.producto!.precio.toString();
    }
  }

  Future<void> seleccionarImagen() async {
    if (_guardando) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      imagenBytes = bytes;
    });
  }

  Future<void> guardar() async {
    if (_guardando) return;

    final nombre = nombreCtrl.text.trim();
    final descripcion = descripcionCtrl.text.trim();
    final precioTexto = precioCtrl.text.trim();
    final esEdicion = widget.producto != null;
    final urlExistente = widget.producto?.imageUrl?.trim();
    final tieneUrlExistente = urlExistente != null && urlExistente.isNotEmpty;

    if (nombre.isEmpty || descripcion.isEmpty || precioTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    if (imagenBytes == null && (!esEdicion || !tieneUrlExistente)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Seleccione una fotografía para el producto"),
        ),
      );
      return;
    }

    final precio = double.tryParse(precioTexto);
    if (precio == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Precio inválido")));
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      String imageUrlFinal;
      if (imagenBytes != null) {
        final imageUrlSubida = await subirImagenStorage(imagenBytes!);
        if (!mounted) return;

        if (imageUrlSubida == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error subiendo imagen')),
          );
          return;
        }
        imageUrlFinal = imageUrlSubida;
      } else {
        imageUrlFinal = urlExistente!;
      }

      final producto = Producto(
        id:
            widget.producto?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: nombre,
        descripcion: descripcion,
        precio: precio,
        imageUrl: imageUrlFinal,
      );

      await ProductoController.guardarProducto(producto);
      if (!mounted) return;

      if (widget.integrado) {
        widget.onGuardado?.call();
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el producto. Intenta nuevamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  void _cancelar() {
    if (_guardando) return;

    if (widget.integrado) {
      widget.onCancelar?.call();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    descripcionCtrl.dispose();
    precioCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoracionCampo({
    required String label,
    required String hint,
    required IconData icono,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icono, color: _grisTexto, size: 20),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _grisTexto, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _bordeSuave, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _rojoMarca, width: 1.8),
      ),
    );
  }

  Widget _construirSelectorImagen() {
    final urlExistente = widget.producto?.imageUrl?.trim();
    final tieneUrlExistente = urlExistente != null && urlExistente.isNotEmpty;
    final tieneVistaPrevia = imagenBytes != null || tieneUrlExistente;

    Widget contenidoImagen;
    if (imagenBytes != null) {
      contenidoImagen = Image.memory(
        imagenBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (tieneUrlExistente) {
      contenidoImagen = Image.network(
        urlExistente,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholderImagen(),
      );
    } else {
      contenidoImagen = _placeholderImagen();
    }

    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: _guardando ? null : seleccionarImagen,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: _rosaSuave,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _bordeSuave, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: contenidoImagen,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _guardando ? null : seleccionarImagen,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(
              tieneVistaPrevia
                  ? 'Cambiar fotografía'
                  : 'Seleccionar fotografía',
            ),
            style: TextButton.styleFrom(
              foregroundColor: _rojoMarca,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImagen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.add_photo_alternate_outlined, size: 40, color: _rojoMarca),
        SizedBox(height: 8),
        Text(
          'Sin imagen',
          style: TextStyle(
            fontSize: 13,
            color: _grisTexto,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _construirFormulario(BuildContext context) {
    final esEdicion = widget.producto != null;
    final titulo = esEdicion ? 'Editar producto' : 'Registrar producto';
    final textoGuardar = esEdicion ? 'Actualizar producto' : 'Guardar producto';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _bordeSuave),
                boxShadow: [
                  BoxShadow(
                    color: _rojoMarca.withValues(alpha: 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.integrado) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _guardando ? null : _cancelar,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Volver a Productos'),
                        style: TextButton.styleFrom(
                          foregroundColor: _grisTexto,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _negroElegante,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    esEdicion
                        ? 'Actualiza los datos o cambia la fotografía del producto.'
                        : 'Completa la información y selecciona una fotografía para el catálogo.',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _grisTexto,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _construirSelectorImagen(),
                  const SizedBox(height: 22),
                  TextField(
                    controller: nombreCtrl,
                    enabled: !_guardando,
                    textInputAction: TextInputAction.next,
                    decoration: _decoracionCampo(
                      label: 'Nombre',
                      hint: 'Ej. Pulsera de acero inoxidable',
                      icono: Icons.shopping_bag_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descripcionCtrl,
                    enabled: !_guardando,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                    decoration: _decoracionCampo(
                      label: 'Descripción',
                      hint: 'Detalles, material o características',
                      icono: Icons.description_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: precioCtrl,
                    enabled: !_guardando,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => guardar(),
                    decoration: _decoracionCampo(
                      label: 'Precio (L.)',
                      hint: '0.00',
                      icono: Icons.attach_money_rounded,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: _guardando ? null : _cancelar,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _grisTexto,
                          side: const BorderSide(color: _bordeSuave),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: _guardando ? null : guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rojoMarca,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _rojoMarca.withValues(
                            alpha: 0.6,
                          ),
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _guardando
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Guardando...'),
                                ],
                              )
                            : Text(
                                textoGuardar,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.integrado) {
      return _construirFormulario(context);
    }

    final titulo = widget.producto == null
        ? 'Registrar producto'
        : 'Editar producto';

    return Scaffold(
      backgroundColor: _fondoClaro,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _rojoMarca),
        shape: const Border(bottom: BorderSide(color: _bordeSuave, width: 1)),
        title: Text(
          titulo,
          style: const TextStyle(
            color: _rojoMarca,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, _fondoClaro, _rosaSuave],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: _construirFormulario(context),
            ),
          ),
        ],
      ),
    );
  }
}
