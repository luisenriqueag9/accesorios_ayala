import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/categoria_controller.dart';
import '../models/categoria.dart';

class GestionCategoriasView extends StatefulWidget {
  final bool integrado;
  final Future<List<Categoria>> Function()? onCargarCategorias;
  final Future<Categoria> Function(Categoria categoria)? onGuardarCategoria;
  final Future<Categoria> Function(Categoria categoria)? onActualizarCategoria;
  final Future<void> Function(String categoriaId, bool visible)?
  onCambiarVisibilidad;

  const GestionCategoriasView({
    super.key,
    this.integrado = false,
    this.onCargarCategorias,
    this.onGuardarCategoria,
    this.onActualizarCategoria,
    this.onCambiarVisibilidad,
  });

  @override
  State<GestionCategoriasView> createState() => _GestionCategoriasViewState();
}

class _GestionCategoriasViewState extends State<GestionCategoriasView> {
  static const Color _rojoMarca = Color(0xFFD9232E);
  static const Color _rosaSuave = Color(0xFFFFF1F2);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0DDE0);

  List<Categoria> _categorias = [];
  bool _cargando = true;
  String? _errorCarga;
  final Set<String> _idsActualizandoVisibilidad = <String>{};

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  String _mensajeErrorAmigable(Object error, {required String accion}) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
        case 'unauthenticated':
          return 'No tienes permisos suficientes para $accion categorías.';
        case 'unavailable':
        case 'deadline-exceeded':
        case 'network-request-failed':
          return 'Error de conexión con Firestore. Verifica tu internet e intenta nuevamente.';
        case 'not-found':
          return 'La categoría ya no existe en Firestore. Actualiza la lista.';
        default:
          return error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : 'No se pudo $accion la categoría en Firestore.';
      }
    }
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Datos inválidos para la categoría.';
    }
    return 'Ocurrió un error inesperado al $accion categorías.';
  }

  void _mostrarSnackBar(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red.shade700 : const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _cargarCategorias() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final cargador =
          widget.onCargarCategorias ??
          () => CategoriaController.cargarCategorias();
      final lista = await cargador();
      if (!mounted) return;
      setState(() {
        _categorias = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = _mensajeErrorAmigable(e, accion: 'consultar');
        _cargando = false;
      });
    }
  }

  int _ordenSugerido() {
    if (_categorias.isEmpty) return 1;
    var maxOrden = _categorias.first.orden;
    for (final cat in _categorias) {
      if (cat.orden > maxOrden) maxOrden = cat.orden;
    }
    return maxOrden + 1;
  }

  Future<void> _cambiarVisibilidad(Categoria categoria, bool visible) async {
    if (_idsActualizandoVisibilidad.contains(categoria.id)) return;

    setState(() {
      _idsActualizandoVisibilidad.add(categoria.id);
    });

    try {
      final cambiar =
          widget.onCambiarVisibilidad ?? CategoriaController.cambiarVisibilidad;
      await cambiar(categoria.id, visible);
      if (!mounted) return;

      setState(() {
        _categorias = _categorias
            .map(
              (c) => c.id == categoria.id
                  ? Categoria(
                      id: c.id,
                      nombre: c.nombre,
                      orden: c.orden,
                      visible: visible,
                    )
                  : c,
            )
            .toList();
      });

      _mostrarSnackBar(
        visible
            ? 'Categoría "${categoria.nombre}" activada en el catálogo.'
            : 'Categoría "${categoria.nombre}" ocultada del catálogo.',
      );
    } catch (e) {
      _mostrarSnackBar(
        _mensajeErrorAmigable(e, accion: 'actualizar'),
        esError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _idsActualizandoVisibilidad.remove(categoria.id);
        });
      }
    }
  }

  Future<void> _abrirDialogoCategoria({Categoria? categoriaExistente}) async {
    final esEdicion = categoriaExistente != null;
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(
      text: categoriaExistente?.nombre ?? '',
    );
    final ordenCtrl = TextEditingController(
      text: (categoriaExistente?.orden ?? _ordenSugerido()).toString(),
    );
    var visibleInicial = categoriaExistente?.visible ?? true;
    var guardando = false;
    String? errorDialogo;

    final guardada = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> enviar() async {
              if (guardando) return;
              if (!(formKey.currentState?.validate() ?? false)) return;

              final nombre = nombreCtrl.text.trim();
              final orden = int.parse(ordenCtrl.text.trim());

              setDialogState(() {
                guardando = true;
                errorDialogo = null;
              });

              try {
                if (esEdicion) {
                  final actualizar =
                      widget.onActualizarCategoria ??
                      CategoriaController.actualizarCategoria;
                  await actualizar(
                    Categoria(
                      id: categoriaExistente.id,
                      nombre: nombre,
                      orden: orden,
                      visible: categoriaExistente.visible,
                    ),
                  );
                } else {
                  final guardar =
                      widget.onGuardarCategoria ??
                      CategoriaController.guardarCategoria;
                  await guardar(
                    Categoria(
                      id: '',
                      nombre: nombre,
                      orden: orden,
                      visible: visibleInicial,
                    ),
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    guardando = false;
                    errorDialogo = _mensajeErrorAmigable(
                      e,
                      accion: esEdicion ? 'actualizar' : 'guardar',
                    );
                  });
                }
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                esEdicion ? 'Editar categoría' : 'Nueva categoría',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _negroElegante,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nombreCtrl,
                        enabled: !guardando,
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: 'Nombre de la categoría',
                          hintText: 'Ej. Pulseras, Grabados láser...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final limpio = (value ?? '').trim();
                          if (limpio.isEmpty) {
                            return 'El nombre es obligatorio.';
                          }
                          if (limpio.length > 80) {
                            return 'Máximo 80 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ordenCtrl,
                        enabled: !guardando,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Orden de visualización',
                          hintText: 'Ej. 1, 2, 3...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          final texto = (value ?? '').trim();
                          if (texto.isEmpty || int.tryParse(texto) == null) {
                            return 'Ingresa un número entero válido.';
                          }
                          return null;
                        },
                      ),
                      if (!esEdicion) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Visible en el catálogo público',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: visibleInicial,
                          activeThumbColor: _rojoMarca,
                          onChanged: guardando
                              ? null
                              : (valor) {
                                  setDialogState(() {
                                    visibleInicial = valor;
                                  });
                                },
                        ),
                      ],
                      if (errorDialogo != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _rosaSuave,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _bordeSuave),
                          ),
                          child: Text(
                            errorDialogo!,
                            style: const TextStyle(
                              color: _rojoMarca,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: guardando ? null : enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rojoMarca,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    guardando
                        ? 'Guardando...'
                        : (esEdicion ? 'Guardar cambios' : 'Crear categoría'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nombreCtrl.dispose();
    ordenCtrl.dispose();

    if (guardada == true && mounted) {
      await _cargarCategorias();
      _mostrarSnackBar(
        esEdicion
            ? 'Categoría actualizada correctamente.'
            : 'Categoría creada correctamente.',
      );
    }
  }

  Widget _construirEncabezado({required bool esEscritorio}) {
    final activas = _categorias.where((c) => c.visible).length;
    final ocultas = _categorias.length - activas;

    final acciones = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: _cargando ? null : _cargarCategorias,
          style: OutlinedButton.styleFrom(
            foregroundColor: _negroElegante,
            side: const BorderSide(color: _bordeSuave),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Actualizar'),
        ),
        ElevatedButton.icon(
          onPressed: _cargando ? null : () => _abrirDialogoCategoria(),
          style: ElevatedButton.styleFrom(
            backgroundColor: _rojoMarca,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text(
            'Nueva categoría',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(esEscritorio ? 22 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bordeSuave),
      ),
      child: esEscritorio
          ? Row(
              children: [
                Expanded(
                  child: _construirTituloEncabezado(
                    activas: activas,
                    ocultas: ocultas,
                  ),
                ),
                const SizedBox(width: 16),
                acciones,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _construirTituloEncabezado(
                  activas: activas,
                  ocultas: ocultas,
                ),
                const SizedBox(height: 14),
                acciones,
              ],
            ),
    );
  }

  Widget _construirTituloEncabezado({
    required int activas,
    required int ocultas,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categorías',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _negroElegante,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _categorias.isEmpty
              ? 'Administra las categorías visibles en el catálogo público.'
              : '${_categorias.length} registradas · $activas visibles · $ocultas ocultas',
          style: const TextStyle(fontSize: 13.5, color: _grisTexto),
        ),
      ],
    );
  }

  Widget _construirEstadoCargando() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bordeSuave),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _rojoMarca),
          SizedBox(height: 14),
          Text(
            'Cargando categorías...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _negroElegante,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 42, color: _rojoMarca),
          const SizedBox(height: 12),
          Text(
            _errorCarga ?? 'No se pudieron cargar las categorías.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarCategorias,
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoVacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _bordeSuave),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _rosaSuave,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.category_outlined,
              size: 36,
              color: _rojoMarca,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No hay categorías registradas',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _negroElegante,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Crea categorías desde aquí para organizar los productos del catálogo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: _grisTexto),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _abrirDialogoCategoria(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoMarca,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear primera categoría'),
          ),
        ],
      ),
    );
  }

  Widget _construirBadgeEstado(bool visible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: visible ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visible ? 'Visible' : 'Oculta',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: visible ? const Color(0xFF2E7D32) : _grisTexto,
        ),
      ),
    );
  }

  Widget _construirTarjetaCategoria(
    Categoria categoria, {
    required bool esEscritorio,
  }) {
    final guardandoVisibilidad = _idsActualizandoVisibilidad.contains(
      categoria.id,
    );

    final badgeOrden = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _rosaSuave,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bordeSuave),
      ),
      child: Text(
        'Orden ${categoria.orden}',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: _rojoMarca,
        ),
      ),
    );

    final controles = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: guardandoVisibilidad
              ? null
              : () => _abrirDialogoCategoria(categoriaExistente: categoria),
          style: OutlinedButton.styleFrom(
            foregroundColor: _negroElegante,
            side: const BorderSide(color: _bordeSuave),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Editar'),
        ),
        const SizedBox(width: 10),
        Switch(
          value: categoria.visible,
          activeThumbColor: _rojoMarca,
          onChanged: guardandoVisibilidad
              ? null
              : (valor) => _cambiarVisibilidad(categoria, valor),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(esEscritorio ? 16 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bordeSuave),
      ),
      child: esEscritorio
          ? Row(
              children: [
                badgeOrden,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    categoria.nombre,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: _negroElegante,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _construirBadgeEstado(categoria.visible),
                const SizedBox(width: 14),
                controles,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    badgeOrden,
                    const SizedBox(width: 8),
                    _construirBadgeEstado(categoria.visible),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  categoria.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _negroElegante,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [controles],
                ),
              ],
            ),
    );
  }

  Widget _construirContenido(bool esEscritorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _construirEncabezado(esEscritorio: esEscritorio),
        const SizedBox(height: 16),
        if (_cargando)
          _construirEstadoCargando()
        else if (_errorCarga != null)
          _construirEstadoError()
        else if (_categorias.isEmpty)
          _construirEstadoVacio()
        else
          for (final cat in _categorias)
            _construirTarjetaCategoria(cat, esEscritorio: esEscritorio),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final esEscritorio = constraints.maxWidth >= 700;
        final contenido = _construirContenido(esEscritorio);

        if (widget.integrado) {
          return contenido;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _rojoMarca),
            title: const Text(
              'Categorías',
              style: TextStyle(
                color: _rojoMarca,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(esEscritorio ? 24 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: contenido,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
