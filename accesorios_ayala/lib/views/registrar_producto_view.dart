import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/producto.dart';
import '../models/categoria.dart';
import '../controllers/producto_controller.dart';
import '../controllers/categoria_controller.dart';

class RegistrarProductoView extends StatefulWidget {
  final Producto? producto;
  final bool integrado;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [CategoriaController.cargarCategorias].
  final Future<List<Categoria>> Function()? cargarCategorias;

  /// Inyección opcional para pruebas. Si es `null` se usa
  /// [ProductoController.guardarProducto].
  final Future<void> Function(Producto producto)? guardarProducto;

  const RegistrarProductoView({
    super.key,
    this.producto,
    this.integrado = false,
    this.onGuardado,
    this.onCancelar,
    this.cargarCategorias,
    this.guardarProducto,
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

  // Categorías: la selección parte SIEMPRE de las asignadas al producto y
  // nunca se filtra contra las categorías cargadas (preserva ocultas y no
  // disponibles). Solo cambia por acción explícita del administrador.
  final Set<String> _categoriasSeleccionadas = <String>{};
  List<Categoria> _categorias = const [];
  bool _cargandoCategorias = true;
  String? _errorCategorias;

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

    _categoriasSeleccionadas.addAll(
      widget.producto?.categoriaIds ?? const <String>[],
    );
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    if (_errorCategorias != null || !_cargandoCategorias) {
      // Reintento: initState ya marcó la carga inicial sin setState.
      setState(() {
        _cargandoCategorias = true;
        _errorCategorias = null;
      });
    }

    try {
      final categorias = await (widget.cargarCategorias ??
          CategoriaController.cargarCategorias)();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _cargandoCategorias = false;
      });
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
      if (!mounted) return;
      setState(() {
        _cargandoCategorias = false;
        _errorCategorias = 'No se pudieron cargar las categorías.';
      });
    }
  }

  void _alternarCategoria(String id, bool seleccionar) {
    if (_guardando) return;
    setState(() {
      if (seleccionar) {
        _categoriasSeleccionadas.add(id);
      } else {
        _categoriasSeleccionadas.remove(id);
      }
    });
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
        visibleCatalogo: widget.producto?.visibleCatalogo ?? true,
        categoriaIds: _categoriasSeleccionadas.toList(),
      );

      await (widget.guardarProducto ?? ProductoController.guardarProducto)(
        producto,
      );
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

  Widget _chipCategoria({
    required String id,
    required String etiqueta,
    String? insignia,
  }) {
    final seleccionada = _categoriasSeleccionadas.contains(id);
    return FilterChip(
      key: ValueKey('chip-categoria-$id'),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(etiqueta, overflow: TextOverflow.ellipsis)),
          if (insignia != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                insignia,
                style: const TextStyle(
                  fontSize: 11,
                  color: _grisTexto,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: seleccionada,
      onSelected: _guardando
          ? null
          : (valor) => _alternarCategoria(id, valor),
      showCheckmark: true,
      checkmarkColor: _rojoMarca,
      selectedColor: _rosaSuave,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: seleccionada ? _rojoMarca : _bordeSuave,
        width: 1.2,
      ),
      labelStyle: TextStyle(
        color: seleccionada ? _rojoMarca : _negroElegante,
        fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _construirSeccionCategorias() {
    final idsCargados = _categorias.map((c) => c.id).toSet();

    // Visibles: siempre ofrecidas. Ocultas: solo si ya estaban seleccionadas.
    final chips = <Widget>[
      for (final c in _categorias)
        if (c.visible || _categoriasSeleccionadas.contains(c.id))
          _chipCategoria(
            id: c.id,
            etiqueta: c.nombre,
            insignia: c.visible ? null : 'Oculta',
          ),
    ];

    // IDs asignados que no aparecen en la consulta: se conservan y se
    // muestran solo cuando la carga fue exitosa (si falló, no se sabe).
    final noDisponibles = (_cargandoCategorias || _errorCategorias != null)
        ? const <String>[]
        : _categoriasSeleccionadas
              .where((id) => !idsCargados.contains(id))
              .toList();
    for (final id in noDisponibles) {
      chips.add(
        _chipCategoria(
          id: id,
          etiqueta: 'Categoría no disponible',
          insignia: 'No encontrada',
        ),
      );
    }

    Widget contenido;
    if (_cargandoCategorias) {
      contenido = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _rojoMarca,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Cargando categorías...',
              style: TextStyle(fontSize: 13, color: _grisTexto),
            ),
          ],
        ),
      );
    } else if (_errorCategorias != null) {
      final asignadas = _categoriasSeleccionadas.length;
      contenido = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          const Icon(Icons.error_outline, size: 18, color: _rojoMarca),
          Text(
            asignadas > 0
                ? '$_errorCategorias Se conservarán las $asignadas asignadas.'
                : _errorCategorias!,
            style: const TextStyle(fontSize: 13, color: _grisTexto),
          ),
          TextButton.icon(
            key: const ValueKey('btn-reintentar-categorias'),
            onPressed: _guardando ? null : _cargarCategorias,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(foregroundColor: _rojoMarca),
          ),
        ],
      );
    } else if (chips.isEmpty) {
      contenido = const Text(
        'No hay categorías activas disponibles.',
        style: TextStyle(fontSize: 13, color: _grisTexto),
      );
    } else {
      contenido = Wrap(spacing: 8, runSpacing: 8, children: chips);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bordeSuave, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sell_outlined, size: 20, color: _grisTexto),
              SizedBox(width: 8),
              Text(
                'Categorías',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: _negroElegante,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Opcional. Puedes seleccionar varias.',
            style: TextStyle(fontSize: 12.5, color: _grisTexto),
          ),
          const SizedBox(height: 10),
          contenido,
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
                  const SizedBox(height: 20),
                  _construirSeccionCategorias(),
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
