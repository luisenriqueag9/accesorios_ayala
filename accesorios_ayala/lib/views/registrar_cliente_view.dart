import 'dart:ui';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/cliente.dart';
import '../controllers/cliente_controller.dart';
import '../utils/widgets/glass_container.dart';

class RegistrarClienteView extends StatefulWidget {
  final Cliente? cliente;
  final bool integrado;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const RegistrarClienteView({
    super.key,
    this.cliente,
    this.integrado = false,
    this.onGuardado,
    this.onCancelar,
  });

  @override
  State<RegistrarClienteView> createState() => _RegistrarClienteViewState();
}

class _RegistrarClienteViewState extends State<RegistrarClienteView> {
  static const Color _rojoPrincipal = Color(0xFFD9232E);
  static const Color _rojoSuave = Color(0xFFE53935);
  static const Color _rosaSuave = Color(0xFFFFF1F1);
  static const Color _negroElegante = Color(0xFF202020);
  static const Color _grisTexto = Color(0xFF6E6566);
  static const Color _bordeSuave = Color(0xFFF0D4D6);

  // Reglas de longitud exacta para los países más frecuentes
  static const Map<String, int> _longitudesExactasPorPais = {
    'HN': 8,
    'GT': 8,
    'SV': 8,
    'NI': 8,
    'CR': 8,
    'PA': 8,
    'BO': 8,
    'BZ': 7,
    'US': 10,
    'CA': 10,
    'MX': 10,
    'DO': 10,
    'PR': 10,
    'CO': 10,
    'AR': 10,
    'VE': 10,
    'ES': 9,
    'PE': 9,
    'CL': 9,
    'EC': 9,
    'PY': 9,
    'UY': 9,
  };

  final nombreCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();

  late Country _paisSeleccionado = Country.parse('HN');
  String _codigoPaisInicial = 'HN';
  String? _telefonoAmbiguoOriginal;
  bool _paisModificado = false;
  bool _departamentoModificado = false;

  String departamentoSeleccionado = "Cortés";
  String? _errorTelefono;
  bool _guardando = false;

  bool get _esHonduras => _paisSeleccionado.countryCode == 'HN';

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
      _cargarTelefonoExistente(widget.cliente!.telefono);
      _codigoPaisInicial = _paisSeleccionado.countryCode;
      direccionCtrl.text = widget.cliente!.direccion;
      if (departamentos.contains(widget.cliente!.departamento)) {
        departamentoSeleccionado = widget.cliente!.departamento;
      } else {
        departamentoSeleccionado = "Cortés";
      }
    }
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    telefonoCtrl.dispose();
    direccionCtrl.dispose();
    super.dispose();
  }

  ({int min, int max, String ejemplo}) _reglaLongitudPais(Country pais) {
    final maxE164 = (15 - pais.phoneCode.length).clamp(4, 15);
    final ejemploCatalogo = pais.example.replaceAll(RegExp(r'\D'), '');

    if (pais.countryCode == 'HN') {
      return (min: 8, max: 8, ejemplo: '98765432');
    }

    final longitudExacta = _longitudesExactasPorPais[pais.countryCode];
    if (longitudExacta != null) {
      final ejemplo = ejemploCatalogo.isNotEmpty
          ? ejemploCatalogo
          : '9' * longitudExacta;
      return (min: longitudExacta, max: longitudExacta, ejemplo: ejemplo);
    }

    if (pais.countryCode == 'BR') {
      return (
        min: 10,
        max: 11,
        ejemplo: ejemploCatalogo.isNotEmpty ? ejemploCatalogo : '11987654321',
      );
    }

    if (ejemploCatalogo.isNotEmpty) {
      final base = ejemploCatalogo.length;
      final minLen = (base - 1).clamp(4, maxE164);
      final maxLen = (base + 1).clamp(minLen, maxE164);
      return (min: minLen, max: maxLen, ejemplo: ejemploCatalogo);
    }

    return (min: 6, max: maxE164, ejemplo: '12345678');
  }

  bool _esLongitudNacionalValida(Country pais, String digitosNacionales) {
    if (!RegExp(r'^\d+$').hasMatch(digitosNacionales)) return false;
    final regla = _reglaLongitudPais(pais);
    return digitosNacionales.length >= regla.min &&
        digitosNacionales.length <= regla.max &&
        (pais.phoneCode.length + digitosNacionales.length) <= 15;
  }

  void _cargarTelefonoExistente(String telefonoGuardado) {
    final original = telefonoGuardado.trim();
    final limpio = original.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Caso 1: Teléfono antiguo hondureño de 8 dígitos sin '+'
    if (!limpio.startsWith('+') && RegExp(r'^\d{8}$').hasMatch(limpio)) {
      _paisSeleccionado = Country.parse('HN');
      telefonoCtrl.text = limpio;
      _telefonoAmbiguoOriginal = null;
      return;
    }

    // Caso 2: Teléfono internacional con '+'
    if (RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(limpio)) {
      final digitosSinMas = limpio.substring(1);
      final todosLosPaises = CountryService().getAll()
        ..removeWhere((c) => c.phoneCode.isEmpty || c.iswWorldWide)
        ..sort((a, b) {
          final cmpLen = b.phoneCode.length.compareTo(a.phoneCode.length);
          if (cmpLen != 0) return cmpLen;
          return a.level.compareTo(b.level);
        });

      for (final candidato in todosLosPaises) {
        if (digitosSinMas.startsWith(candidato.phoneCode)) {
          final nacional = digitosSinMas.substring(candidato.phoneCode.length);
          if (_esLongitudNacionalValida(candidato, nacional)) {
            _paisSeleccionado = candidato;
            telefonoCtrl.text = nacional;
            _telefonoAmbiguoOriginal = null;
            return;
          }
        }
      }
    }

    // Caso 3: Formato ambiguo -> se conserva tal cual hasta que el usuario decida editarlo
    _paisSeleccionado = Country.parse('HN');
    telefonoCtrl.text = telefonoGuardado;
    _telefonoAmbiguoOriginal = telefonoGuardado;
  }

  void _abrirSelectorPais() {
    final anchoPantalla = MediaQuery.sizeOf(context).width;

    showCountryPicker(
      context: context,
      showPhoneCode: true,
      showSearch: true,
      favorite: const ['HN', 'US', 'MX', 'ES', 'GT', 'SV', 'NI', 'CR', 'PA'],
      countryListTheme: CountryListThemeData(
        backgroundColor: Colors.white,
        bottomSheetHeight: 540,
        bottomSheetWidth: anchoPantalla > 600 ? 520 : null,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        flagSize: 24,
        emojiFontFamilyFallback: const [
          'Noto Color Emoji',
          'Segoe UI Emoji',
          'Apple Color Emoji',
        ],
        textStyle: const TextStyle(
          color: _negroElegante,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        searchTextStyle: const TextStyle(color: _negroElegante, fontSize: 15),
        inputDecoration: InputDecoration(
          labelText: 'Buscar país o código',
          hintText: 'Ej. Honduras, Estados Unidos, +504...',
          prefixIcon: const Icon(Icons.search_rounded, color: _rojoPrincipal),
          filled: true,
          fillColor: _rosaSuave.withValues(alpha: 0.45),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bordeSuave, width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bordeSuave, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _rojoSuave, width: 1.8),
          ),
        ),
      ),
      onSelect: (Country nuevoPais) {
        setState(() {
          _paisSeleccionado = nuevoPais;
          _paisModificado = nuevoPais.countryCode != _codigoPaisInicial;
          _errorTelefono = null;
        });
      },
    );
  }

  String _mensajeErrorLongitud(Country pais) {
    final regla = _reglaLongitudPais(pais);
    if (regla.min == regla.max) {
      return 'Ingresa ${regla.min} dígitos para ${pais.name} (ej. ${regla.ejemplo})';
    }
    return 'Ingresa entre ${regla.min} y ${regla.max} dígitos para ${pais.name} (ej. ${regla.ejemplo})';
  }

  Future<void> guardar() async {
    if (_guardando) return;

    if (nombreCtrl.text.trim().isEmpty ||
        telefonoCtrl.text.trim().isEmpty ||
        direccionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete todos los campos")),
      );
      return;
    }

    final textoTelefono = telefonoCtrl.text.trim();
    String telefonoParaGuardar;

    // Si es un cliente existente con teléfono ambiguo y no fue modificado, conservarlo intacto
    if (widget.cliente != null &&
        _telefonoAmbiguoOriginal != null &&
        telefonoCtrl.text == _telefonoAmbiguoOriginal) {
      telefonoParaGuardar = _telefonoAmbiguoOriginal!;
    } else {
      if (!_esLongitudNacionalValida(_paisSeleccionado, textoTelefono)) {
        final mensaje = _mensajeErrorLongitud(_paisSeleccionado);
        setState(() {
          _errorTelefono = mensaje;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensaje)));
        return;
      }

      telefonoParaGuardar = '+${_paisSeleccionado.phoneCode}$textoTelefono';
    }

    final String departamentoParaGuardar =
        (widget.cliente != null && !_paisModificado && !_departamentoModificado)
        ? widget.cliente!.departamento
        : (_esHonduras ? departamentoSeleccionado : 'Internacional');

    final cliente = Cliente(
      id: widget.cliente?.id ?? "",
      nombre: nombreCtrl.text.trim(),
      telefono: telefonoParaGuardar,
      direccion: direccionCtrl.text.trim(),
      departamento: departamentoParaGuardar,
    );

    setState(() {
      _guardando = true;
    });

    try {
      if (widget.cliente == null) {
        await ClienteController.agregarCliente(cliente);
      } else {
        await ClienteController.editarCliente(cliente);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.cliente == null
                ? "Cliente agregado correctamente"
                : "Cliente actualizado",
          ),
        ),
      );

      if (widget.integrado) {
        widget.onGuardado?.call();
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar el cliente. Intenta nuevamente.'),
          backgroundColor: Colors.red,
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
      Navigator.of(context).maybePop();
    }
  }

  InputDecoration _decoracionCampo({
    required String label,
    required String hint,
    required IconData icono,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: _grisTexto,
        fontWeight: FontWeight.w500,
        fontSize: 14.5,
      ),
      floatingLabelStyle: const TextStyle(
        color: _rojoPrincipal,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: _grisTexto.withValues(alpha: 0.65),
        fontSize: 14.5,
      ),
      prefixIcon: Icon(
        icono,
        color: _rojoPrincipal.withValues(alpha: 0.85),
        size: 22,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _bordeSuave, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _bordeSuave, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _rojoSuave, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _rojoPrincipal, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _rojoPrincipal, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.cliente != null;
    final anchoPantalla = MediaQuery.sizeOf(context).width;
    final esMovil = anchoPantalla < 600;

    if (widget.integrado) {
      return Center(
        child: _construirTarjetaFormulario(
          esEdicion: esEdicion,
          esMovil: esMovil,
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _rosaSuave,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.78),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leadingWidth: 64,
              leading: Padding(
                padding: const EdgeInsets.only(left: 14, top: 10, bottom: 10),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _guardando ? null : _cancelar,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _bordeSuave, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: _rojoPrincipal,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              title: Text(
                esEdicion ? "Editar Cliente" : "Registrar Cliente",
                style: const TextStyle(
                  color: _rojoPrincipal,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  height: 1,
                  color: _bordeSuave.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _fondoDegradado(),
          _fondoBlur(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: esMovil ? 18 : 28,
                  vertical: esMovil ? 20 : 32,
                ),
                child: _construirTarjetaFormulario(
                  esEdicion: esEdicion,
                  esMovil: esMovil,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaFormulario({
    required bool esEdicion,
    required bool esMovil,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _rojoPrincipal.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: GlassContainer(
          blur: 18,
          opacity: 0.72,
          borderRadius: 24,
          padding: EdgeInsets.symmetric(
            horizontal: esMovil ? 20 : 30,
            vertical: esMovil ? 24 : 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.integrado) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _guardando ? null : _cancelar,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Volver a Clientes'),
                    style: TextButton.styleFrom(
                      foregroundColor: _grisTexto,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Encabezado del formulario
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _bordeSuave),
                      boxShadow: [
                        BoxShadow(
                          color: _rojoPrincipal.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      esEdicion
                          ? Icons.manage_accounts_rounded
                          : Icons.person_add_alt_1_rounded,
                      color: _rojoPrincipal,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion
                              ? "Actualizar información"
                              : "Nuevo cliente",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _negroElegante,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Completa los datos de contacto y ubicación",
                          style: TextStyle(
                            fontSize: 13,
                            color: _grisTexto.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Campo: Nombre
              TextField(
                controller: nombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: _negroElegante, fontSize: 15.5),
                decoration: _decoracionCampo(
                  label: "Nombre completo",
                  hint: "Ej. María Fernanda López",
                  icono: Icons.person_outline_rounded,
                ),
              ),

              const SizedBox(height: 18),

              // Campo: Selector de País + Teléfono
              Builder(
                builder: (context) {
                  final reglaPais = _reglaLongitudPais(_paisSeleccionado);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Botón selector de país con bandera y código
                      Tooltip(
                        message:
                            '${_paisSeleccionado.name} (+${_paisSeleccionado.phoneCode})',
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _guardando ? null : _abrirSelectorPais,
                            child: Container(
                              height: 58,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _bordeSuave,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _paisSeleccionado.flagEmoji,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontFamilyFallback: [
                                        'Noto Color Emoji',
                                        'Segoe UI Emoji',
                                        'Apple Color Emoji',
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+${_paisSeleccionado.phoneCode}',
                                    style: const TextStyle(
                                      color: _negroElegante,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: _rojoPrincipal,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Número nacional
                      Expanded(
                        child: TextField(
                          controller: telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: _telefonoAmbiguoOriginal != null
                              ? null
                              : [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                    reglaPais.max,
                                  ),
                                ],
                          onChanged: (valor) {
                            if (_telefonoAmbiguoOriginal != null &&
                                valor != _telefonoAmbiguoOriginal) {
                              final soloDigitos = valor.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              setState(() {
                                _telefonoAmbiguoOriginal = null;
                              });
                              if (soloDigitos != valor) {
                                telefonoCtrl.value = TextEditingValue(
                                  text: soloDigitos,
                                  selection: TextSelection.collapsed(
                                    offset: soloDigitos.length,
                                  ),
                                );
                              }
                            }
                            if (_errorTelefono != null &&
                                _esLongitudNacionalValida(
                                  _paisSeleccionado,
                                  telefonoCtrl.text.trim(),
                                )) {
                              setState(() => _errorTelefono = null);
                            }
                          },
                          style: const TextStyle(
                            color: _negroElegante,
                            fontSize: 15.5,
                          ),
                          decoration: _decoracionCampo(
                            label:
                                "Teléfono (${_paisSeleccionado.countryCode})",
                            hint: "Ej. ${reglaPais.ejemplo}",
                            icono: Icons.phone_iphone_rounded,
                            errorText: _errorTelefono,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Campo: Dirección
              TextField(
                controller: direccionCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: _negroElegante, fontSize: 15.5),
                decoration: _decoracionCampo(
                  label: "Dirección",
                  hint: "Ej. Bo. El Centro, 2da calle",
                  icono: Icons.location_on_outlined,
                ),
              ),

              const SizedBox(height: 18),

              // Campo: Departamento (18 departamentos para HN / solo lectura "Internacional" para otros países)
              if (_esHonduras)
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    departamentos.contains(departamentoSeleccionado)
                        ? departamentoSeleccionado
                        : "Cortés",
                  ),
                  initialValue: departamentos.contains(departamentoSeleccionado)
                      ? departamentoSeleccionado
                      : "Cortés",
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _rojoPrincipal,
                  ),
                  style: const TextStyle(color: _negroElegante, fontSize: 15.5),
                  items: departamentos
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (valor) {
                    if (valor != null) {
                      setState(() {
                        departamentoSeleccionado = valor;
                        _departamentoModificado = true;
                      });
                    }
                  },
                  decoration: _decoracionCampo(
                    label: "Departamento",
                    hint: "Selecciona un departamento",
                    icono: Icons.map_outlined,
                  ),
                )
              else
                TextFormField(
                  key: const ValueKey<String>('departamento_internacional'),
                  initialValue: 'Internacional',
                  readOnly: true,
                  style: const TextStyle(
                    color: _negroElegante,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: _decoracionCampo(
                    label: "Departamento",
                    hint: "Internacional",
                    icono: Icons.public_rounded,
                  ),
                ),

              const SizedBox(height: 28),

              // Botones: Cancelar (en modo integrado) y Guardar Cliente / Guardar Cambios
              if (widget.integrado)
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
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    _construirBotonGuardar(esEdicion),
                  ],
                )
              else
                _construirBotonGuardar(esEdicion),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBotonGuardar(bool esEdicion) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.82),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _guardando
                  ? _rojoPrincipal.withValues(alpha: 0.5)
                  : _rojoPrincipal,
              width: 1.6,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            splashColor: _rojoPrincipal.withValues(alpha: 0.10),
            highlightColor: _rojoPrincipal.withValues(alpha: 0.05),
            onTap: _guardando ? null : guardar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_guardando) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _rojoPrincipal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Guardando...",
                      style: TextStyle(
                        color: _rojoPrincipal,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      esEdicion
                          ? Icons.check_circle_outline_rounded
                          : Icons.save_outlined,
                      color: _rojoPrincipal,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      esEdicion ? "Guardar Cambios" : "Guardar Cliente",
                      style: const TextStyle(
                        color: _rojoPrincipal,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _fondoDegradado() {
  return Stack(
    children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFF4F5), Color(0xFFFFE6E8)],
            stops: [0.0, 0.55, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      Positioned(
        top: -80,
        right: -60,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD9232E).withValues(alpha: 0.12),
                const Color(0xFFD9232E).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: -100,
        left: -70,
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFD9232E).withValues(alpha: 0.10),
                const Color(0xFFD9232E).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _fondoBlur() {
  return BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
    child: Container(color: Colors.white10),
  );
}
