import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de elaboración de un producto individual o del pedido completo.
enum EstadoElaboracionPedido {
  recibido('recibido', 'Recibido'),
  enProceso('en_proceso', 'En proceso'),
  terminado('terminado', 'Terminado');

  final String valorFirestore;
  final String etiqueta;

  const EstadoElaboracionPedido(this.valorFirestore, this.etiqueta);

  static EstadoElaboracionPedido fromValor(String? valor) {
    for (final estado in EstadoElaboracionPedido.values) {
      if (estado.valorFirestore == valor) return estado;
    }
    return EstadoElaboracionPedido.recibido;
  }
}

/// Estado logístico de envío y entrega del pedido, independiente de producción.
enum EstadoEnvioPedido {
  pendiente('pendiente', 'Pendiente'),
  enviado('enviado', 'Enviado'),
  entregado('entregado', 'Entregado');

  final String valorFirestore;
  final String etiqueta;

  const EstadoEnvioPedido(this.valorFirestore, this.etiqueta);

  static EstadoEnvioPedido fromValor(String? valor) {
    for (final estado in EstadoEnvioPedido.values) {
      if (estado.valorFirestore == valor) return estado;
    }
    return EstadoEnvioPedido.pendiente;
  }
}

/// Alerta de entrega calculada respecto al día calendario actual en Honduras.
enum AlertaEntregaPedido {
  sinFecha('Sin fecha'),
  entregado('Entregado'),
  atrasado('Atrasado'),
  hoy('Entrega hoy'),
  manana('Entrega mañana'),
  futura('Entrega futura');

  final String etiqueta;

  const AlertaEntregaPedido(this.etiqueta);
}

double _toDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? defaultValue;
  return defaultValue;
}

int _toInt(dynamic value, {int defaultValue = 1}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? defaultValue;
  return defaultValue;
}

DateTime? _toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

const Duration _desfaseHonduras = Duration(hours: 6);

String _removerTildes(String texto) {
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

  final buffer = StringBuffer();
  for (final codeUnit in texto.runes) {
    final char = String.fromCharCode(codeUnit);
    buffer.write(mapaTildes[char] ?? char);
  }
  return buffer.toString();
}

/// Normaliza un día calendario al mediodía de Honduras (12:00 UTC-6 = 18:00 UTC).
DateTime _normalizarDiaCalendarioHonduras(DateTime fecha) {
  return DateTime.utc(fecha.year, fecha.month, fecha.day, 18);
}

/// Convierte un instante a la fecha calendario vigente en Honduras (UTC-6).
DateTime _fechaCalendarioHondurasDesdeInstante(DateTime instante) {
  final enHonduras = instante.toUtc().subtract(_desfaseHonduras);
  return DateTime.utc(enHonduras.year, enHonduras.month, enHonduras.day);
}

DateTime? _parseFechaPrevista(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) {
    final fechaHn = value.toDate().toUtc().subtract(_desfaseHonduras);
    return _normalizarDiaCalendarioHonduras(fechaHn);
  }
  if (value is DateTime) {
    return _normalizarDiaCalendarioHonduras(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    final texto = value.trim();
    final parsed = DateTime.tryParse(texto);
    if (parsed == null) return null;
    final tieneHoraOZona =
        texto.contains('T') || texto.contains('Z') || texto.contains('+');
    if (tieneHoraOZona) {
      final fechaHn = parsed.toUtc().subtract(_desfaseHonduras);
      return _normalizarDiaCalendarioHonduras(fechaHn);
    }
    return _normalizarDiaCalendarioHonduras(parsed);
  }
  return null;
}

/// Línea de producto dentro de un [Pedido].
///
/// Mantiene un [itemId] estable por línea y conserva el [precioUnitario]
/// acordado en el momento de agregar el producto, independientemente de cambios
/// posteriores en el catálogo.
class PedidoItem {
  final String itemId;
  final String productoId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final String? imageUrl;
  final String notaPersonalizacion;
  final EstadoElaboracionPedido estadoElaboracion;

  PedidoItem({
    required this.itemId,
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.imageUrl,
    this.notaPersonalizacion = '',
    this.estadoElaboracion = EstadoElaboracionPedido.recibido,
  }) {
    if (cantidad < 1) {
      throw ArgumentError.value(
        cantidad,
        'cantidad',
        'La cantidad debe ser mayor o igual a 1.',
      );
    }
    if (precioUnitario < 0) {
      throw ArgumentError.value(
        precioUnitario,
        'precioUnitario',
        'El precio unitario no puede ser negativo.',
      );
    }
  }

  double get subtotal => precioUnitario * cantidad;

  PedidoItem copyWith({
    String? itemId,
    String? productoId,
    String? nombre,
    int? cantidad,
    double? precioUnitario,
    String? imageUrl,
    bool limpiarImageUrl = false,
    String? notaPersonalizacion,
    EstadoElaboracionPedido? estadoElaboracion,
  }) {
    return PedidoItem(
      itemId: itemId ?? this.itemId,
      productoId: productoId ?? this.productoId,
      nombre: nombre ?? this.nombre,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      imageUrl: limpiarImageUrl ? null : (imageUrl ?? this.imageUrl),
      notaPersonalizacion: notaPersonalizacion ?? this.notaPersonalizacion,
      estadoElaboracion: estadoElaboracion ?? this.estadoElaboracion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'productoId': productoId,
      'nombre': nombre,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'imageUrl': imageUrl,
      'notaPersonalizacion': notaPersonalizacion,
      'estadoElaboracion': estadoElaboracion.valorFirestore,
    };
  }

  factory PedidoItem.fromMap(Map<String, dynamic> map) {
    return PedidoItem(
      itemId: (map['itemId'] ?? '').toString(),
      productoId: (map['productoId'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      cantidad: _toInt(map['cantidad'], defaultValue: 1),
      precioUnitario: _toDouble(map['precioUnitario'], defaultValue: 0.0),
      imageUrl: map['imageUrl'] as String?,
      notaPersonalizacion: (map['notaPersonalizacion'] ?? '').toString(),
      estadoElaboracion: EstadoElaboracionPedido.fromValor(
        map['estadoElaboracion'] as String?,
      ),
    );
  }
}

/// Borrador fiscal asociado al pedido antes de confirmarse en Facturación.
///
/// No genera una venta ni asigna un número definitivo de factura hasta que el
/// administrador confirme la emisión desde la pantalla de Facturación.
class BorradorFacturaPedido {
  final double impuestoPorcentaje;
  final bool descuentoMayoristaActivo;
  final double descuentoPorcentaje;
  final double costoEnvio;

  BorradorFacturaPedido({
    this.impuestoPorcentaje = 0.0,
    this.descuentoMayoristaActivo = false,
    this.descuentoPorcentaje = 0.0,
    this.costoEnvio = 0.0,
  }) {
    if (impuestoPorcentaje < 0) {
      throw ArgumentError.value(
        impuestoPorcentaje,
        'impuestoPorcentaje',
        'El porcentaje de impuesto no puede ser negativo.',
      );
    }
    if (descuentoPorcentaje < 0 || descuentoPorcentaje > 100) {
      throw ArgumentError.value(
        descuentoPorcentaje,
        'descuentoPorcentaje',
        'El porcentaje de descuento debe estar entre 0 y 100.',
      );
    }
    if (costoEnvio < 0) {
      throw ArgumentError.value(
        costoEnvio,
        'costoEnvio',
        'El costo de envío no puede ser negativo.',
      );
    }
  }

  double calcularDescuentoMonto(double subtotal) {
    if (subtotal < 0) {
      throw ArgumentError.value(
        subtotal,
        'subtotal',
        'El subtotal no puede ser negativo.',
      );
    }
    if (!descuentoMayoristaActivo) return 0.0;
    return subtotal * (descuentoPorcentaje / 100);
  }

  double calcularImpuestoMonto(double subtotal) {
    final baseImponible = subtotal - calcularDescuentoMonto(subtotal);
    return baseImponible * (impuestoPorcentaje / 100);
  }

  double calcularTotal(double subtotal) {
    final baseImponible = subtotal - calcularDescuentoMonto(subtotal);
    return baseImponible + calcularImpuestoMonto(subtotal) + costoEnvio;
  }

  BorradorFacturaPedido copyWith({
    double? impuestoPorcentaje,
    bool? descuentoMayoristaActivo,
    double? descuentoPorcentaje,
    double? costoEnvio,
  }) {
    return BorradorFacturaPedido(
      impuestoPorcentaje: impuestoPorcentaje ?? this.impuestoPorcentaje,
      descuentoMayoristaActivo:
          descuentoMayoristaActivo ?? this.descuentoMayoristaActivo,
      descuentoPorcentaje: descuentoPorcentaje ?? this.descuentoPorcentaje,
      costoEnvio: costoEnvio ?? this.costoEnvio,
    );
  }

  Map<String, dynamic> toMap({double? subtotalProductos}) {
    final map = <String, dynamic>{
      'impuestoPorcentaje': impuestoPorcentaje,
      'descuentoMayoristaActivo': descuentoMayoristaActivo,
      'descuentoPorcentaje': descuentoPorcentaje,
      'costoEnvio': costoEnvio,
    };

    if (subtotalProductos != null) {
      map['subtotalEstimado'] = subtotalProductos;
      map['totalEstimado'] = calcularTotal(subtotalProductos);
    }

    return map;
  }

  factory BorradorFacturaPedido.fromMap(Map<String, dynamic> map) {
    return BorradorFacturaPedido(
      impuestoPorcentaje: _toDouble(
        map['impuestoPorcentaje'],
        defaultValue: 0.0,
      ),
      descuentoMayoristaActivo: map['descuentoMayoristaActivo'] == true,
      descuentoPorcentaje: _toDouble(
        map['descuentoPorcentaje'],
        defaultValue: 0.0,
      ),
      costoEnvio: _toDouble(map['costoEnvio'], defaultValue: 0.0),
    );
  }
}

/// Modelo principal de un pedido de Accesorios Ayala.
///
/// Convención para [numeroPedido]:
/// - Identificador legible único e independiente del `id` del documento en
///   Firestore (por ejemplo `PED-0001`).
/// - El modelo no genera consecutivos; esa responsabilidad corresponderá al
///   controlador mediante una transacción de Firestore.
/// - Documentos antiguos sin este campo se cargan con `''` sin inventar un
///   consecutivo.
///
/// Convención para [keywordsBusqueda]:
/// - Lista de tokens normalizados (minúsculas, sin tildes ni duplicados)
///   generados a partir de [numeroPedido], [clienteNombre] y los nombres de los
///   productos en [items] (sin almacenar datos sensibles como teléfono o
///   dirección).
/// - Pensada para consultas de Firestore con `arrayContains`, las cuales buscan
///   **tokens exactos** y no subcadenas arbitrarias.
/// - Se recalcula automáticamente en `copyWith` cuando cambian [numeroPedido],
///   [clienteNombre] o [items] para evitar palabras clave desactualizadas.
///
/// Convención para [fechaPrevistaEntrega]:
/// - Representa un día calendario de Honduras (UTC-6 fijo, sin horario de verano),
///   no una hora específica de entrega.
/// - En memoria se normaliza siempre al mediodía de Honduras (`18:00:00Z` UTC)
///   conservando `year`, `month` y `day` del día seleccionado (por ejemplo desde
///   un selector de calendario).
/// - En Firestore se guarda como `Timestamp` a las `18:00:00Z` UTC y al leerse
///   se convierte de UTC a UTC-6 antes de extraer el día calendario, evitando
///   corrimientos por zona horaria del navegador y dobles conversiones.
///
/// Representación de fechas pendientes de asignación por el servidor:
/// - En memoria, [createdAt] y [updatedAt] son `null` cuando el pedido aún no
///   ha recibido marca temporal del servidor de Firestore.
/// - Al serializar con [toMap(incluirMarcadoresServidor: true)], los campos
///   pendientes (`createdAt` cuando es `null`, y siempre `updatedAt` si se
///   solicita marcador de servidor) emiten `FieldValue.serverTimestamp()`.
/// - Al deserializar desde Firestore mediante [fromMap], se aceptan tanto
///   [Timestamp] como cadenas ISO-8601 o `null`.
class Pedido {
  final String id;
  final String numeroPedido;
  final String clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final String clienteDireccion;
  final String clienteDepartamento;
  final List<PedidoItem> items;
  final List<String> keywordsBusqueda;
  final EstadoEnvioPedido estadoEnvio;
  final double costoEnvio;
  final BorradorFacturaPedido borradorFactura;
  final bool facturado;
  final String? ventaId;
  final String? facturaNumero;
  final DateTime? fechaPrevistaEntrega;
  final DateTime? fechaEnvio;
  final DateTime? fechaEntrega;
  final DateTime? fechaFacturacion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Pedido({
    required this.id,
    this.numeroPedido = '',
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono = '',
    this.clienteDireccion = '',
    this.clienteDepartamento = '',
    List<PedidoItem> items = const [],
    List<String>? keywordsBusqueda,
    this.estadoEnvio = EstadoEnvioPedido.pendiente,
    this.costoEnvio = 0.0,
    BorradorFacturaPedido? borradorFactura,
    this.facturado = false,
    this.ventaId,
    this.facturaNumero,
    DateTime? fechaPrevistaEntrega,
    this.fechaEnvio,
    this.fechaEntrega,
    this.fechaFacturacion,
    this.createdAt,
    this.updatedAt,
  }) : items = List.unmodifiable(items),
       keywordsBusqueda = List.unmodifiable(
         keywordsBusqueda ??
             generarKeywordsBusqueda(
               numeroPedido: numeroPedido,
               clienteNombre: clienteNombre,
               items: items,
             ),
       ),
       fechaPrevistaEntrega = fechaPrevistaEntrega != null
           ? _normalizarDiaCalendarioHonduras(fechaPrevistaEntrega)
           : null,
       borradorFactura =
           borradorFactura ?? BorradorFacturaPedido(costoEnvio: costoEnvio) {
    if (costoEnvio < 0) {
      throw ArgumentError.value(
        costoEnvio,
        'costoEnvio',
        'El costo de envío no puede ser negativo.',
      );
    }
  }

  /// Normaliza una cadena a minúsculas, sin tildes y sin espacios extremos.
  static String normalizarTextoBusqueda(String texto) {
    return _removerTildes(texto.trim().toLowerCase());
  }

  /// Genera tokens únicos normalizados para búsquedas con `arrayContains` en
  /// Firestore a partir de [numeroPedido], [clienteNombre] y los nombres de
  /// [items].
  ///
  /// Nota: `arrayContains` en Firestore coincide con tokens exactos de esta
  /// lista, no con subcadenas arbitrarias.
  static List<String> generarKeywordsBusqueda({
    required String numeroPedido,
    required String clienteNombre,
    required List<PedidoItem> items,
  }) {
    final tokens = <String>{};

    void agregarTexto(String texto, {bool conservarCodigoCompleto = false}) {
      final normalizado = normalizarTextoBusqueda(texto);
      if (normalizado.isEmpty) return;

      if (conservarCodigoCompleto) {
        final codigoCompacto = normalizado.replaceAll(RegExp(r'\s+'), '');
        if (codigoCompacto.isNotEmpty) {
          tokens.add(codigoCompacto);
        }
      }

      for (final parte in normalizado.split(RegExp(r'[^a-z0-9]+'))) {
        if (parte.isNotEmpty) {
          tokens.add(parte);
        }
      }
    }

    agregarTexto(numeroPedido, conservarCodigoCompleto: true);
    agregarTexto(clienteNombre);
    for (final item in items) {
      agregarTexto(item.nombre);
    }

    return List.unmodifiable(tokens);
  }

  /// Estado general de producción derivado automáticamente de [items].
  EstadoElaboracionPedido get estadoProduccion {
    if (items.isEmpty) {
      return EstadoElaboracionPedido.recibido;
    }

    final todosRecibidos = items.every(
      (item) => item.estadoElaboracion == EstadoElaboracionPedido.recibido,
    );
    if (todosRecibidos) {
      return EstadoElaboracionPedido.recibido;
    }

    final todosTerminados = items.every(
      (item) => item.estadoElaboracion == EstadoElaboracionPedido.terminado,
    );
    if (todosTerminados) {
      return EstadoElaboracionPedido.terminado;
    }

    return EstadoElaboracionPedido.enProceso;
  }

  /// Indica si todos los accesorios registrados en el pedido están terminados.
  bool get todosAccesoriosTerminados =>
      items.isNotEmpty &&
      items.every(
        (item) => item.estadoElaboracion == EstadoElaboracionPedido.terminado,
      );

  /// Determina si el pedido cumple las condiciones para habilitar la
  /// facturación manual desde el detalle administrativo.
  bool puedeFacturarse({
    bool hayCambiosProvisionales = false,
    bool operacionEnCurso = false,
    bool requiereRecarga = false,
  }) {
    return todosAccesoriosTerminados &&
        !facturado &&
        ventaId == null &&
        !hayCambiosProvisionales &&
        !operacionEnCurso &&
        !requiereRecarga;
  }

  double get subtotalProductos =>
      items.fold(0.0, (acumulado, item) => acumulado + item.subtotal);

  double get totalEstimado => borradorFactura.calcularTotal(subtotalProductos);

  /// Calcula la alerta de entrega comparando días calendario de Honduras (UTC-6).
  ///
  /// El parámetro opcional [referencia] permite pruebas deterministas sin
  /// depender del reloj ni de la zona horaria del sistema.
  AlertaEntregaPedido calcularAlertaEntrega({DateTime? referencia}) {
    if (estadoEnvio == EstadoEnvioPedido.entregado) {
      return AlertaEntregaPedido.entregado;
    }
    if (fechaPrevistaEntrega == null) {
      return AlertaEntregaPedido.sinFecha;
    }

    final hoyHn = _fechaCalendarioHondurasDesdeInstante(
      referencia ?? DateTime.now(),
    );
    final objetivo = DateTime.utc(
      fechaPrevistaEntrega!.year,
      fechaPrevistaEntrega!.month,
      fechaPrevistaEntrega!.day,
    );
    final diferenciaDias = objetivo.difference(hoyHn).inDays;

    if (diferenciaDias < 0) return AlertaEntregaPedido.atrasado;
    if (diferenciaDias == 0) return AlertaEntregaPedido.hoy;
    if (diferenciaDias == 1) return AlertaEntregaPedido.manana;
    return AlertaEntregaPedido.futura;
  }

  Pedido copyWith({
    String? id,
    String? numeroPedido,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteDireccion,
    String? clienteDepartamento,
    List<PedidoItem>? items,
    List<String>? keywordsBusqueda,
    EstadoEnvioPedido? estadoEnvio,
    double? costoEnvio,
    BorradorFacturaPedido? borradorFactura,
    bool? facturado,
    String? ventaId,
    bool limpiarVentaId = false,
    String? facturaNumero,
    bool limpiarFacturaNumero = false,
    DateTime? fechaPrevistaEntrega,
    bool limpiarFechaPrevistaEntrega = false,
    DateTime? fechaEnvio,
    DateTime? fechaEntrega,
    DateTime? fechaFacturacion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final nuevoCostoEnvio = costoEnvio ?? this.costoEnvio;
    final cambioDatosBusqueda =
        numeroPedido != null || clienteNombre != null || items != null;
    final nuevasKeywords =
        keywordsBusqueda ??
        (cambioDatosBusqueda ? null : this.keywordsBusqueda);

    return Pedido(
      id: id ?? this.id,
      numeroPedido: numeroPedido ?? this.numeroPedido,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      clienteDireccion: clienteDireccion ?? this.clienteDireccion,
      clienteDepartamento: clienteDepartamento ?? this.clienteDepartamento,
      items: items ?? this.items,
      keywordsBusqueda: nuevasKeywords,
      estadoEnvio: estadoEnvio ?? this.estadoEnvio,
      costoEnvio: nuevoCostoEnvio,
      borradorFactura:
          borradorFactura ??
          (costoEnvio != null
              ? this.borradorFactura.copyWith(costoEnvio: nuevoCostoEnvio)
              : this.borradorFactura),
      facturado: facturado ?? this.facturado,
      ventaId: limpiarVentaId ? null : (ventaId ?? this.ventaId),
      facturaNumero: limpiarFacturaNumero
          ? null
          : (facturaNumero ?? this.facturaNumero),
      fechaPrevistaEntrega: limpiarFechaPrevistaEntrega
          ? null
          : (fechaPrevistaEntrega ?? this.fechaPrevistaEntrega),
      fechaEnvio: fechaEnvio ?? this.fechaEnvio,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      fechaFacturacion: fechaFacturacion ?? this.fechaFacturacion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convierte el pedido a un mapa compatible con Firestore.
  ///
  /// Cuando [incluirMarcadoresServidor] es `true`, las fechas pendientes de
  /// servidor (`createdAt == null` y `updatedAt`) usan `FieldValue.serverTimestamp()`.
  Map<String, dynamic> toMap({bool incluirMarcadoresServidor = false}) {
    final subtotal = subtotalProductos;

    return {
      'id': id,
      'numeroPedido': numeroPedido,
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'clienteTelefono': clienteTelefono,
      'clienteDireccion': clienteDireccion,
      'clienteDepartamento': clienteDepartamento,
      'items': items.map((item) => item.toMap()).toList(),
      'keywordsBusqueda': keywordsBusqueda,
      'estadoProduccion': estadoProduccion.valorFirestore,
      'estadoEnvio': estadoEnvio.valorFirestore,
      'costoEnvio': costoEnvio,
      'borradorFactura': borradorFactura.toMap(subtotalProductos: subtotal),
      'facturado': facturado,
      'ventaId': ventaId,
      'facturaNumero': facturaNumero,
      'fechaPrevistaEntrega': fechaPrevistaEntrega != null
          ? Timestamp.fromDate(fechaPrevistaEntrega!)
          : null,
      'fechaEnvio': fechaEnvio != null ? Timestamp.fromDate(fechaEnvio!) : null,
      'fechaEntrega': fechaEntrega != null
          ? Timestamp.fromDate(fechaEntrega!)
          : null,
      'fechaFacturacion': fechaFacturacion != null
          ? Timestamp.fromDate(fechaFacturacion!)
          : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : (incluirMarcadoresServidor ? FieldValue.serverTimestamp() : null),
      'updatedAt': incluirMarcadoresServidor
          ? FieldValue.serverTimestamp()
          : (updatedAt != null ? Timestamp.fromDate(updatedAt!) : null),
    };
  }

  factory Pedido.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawItems = map['items'];
    final itemsParseados = <PedidoItem>[];
    if (rawItems is List) {
      for (final elemento in rawItems) {
        if (elemento is Map<String, dynamic>) {
          itemsParseados.add(PedidoItem.fromMap(elemento));
        } else if (elemento is Map) {
          itemsParseados.add(
            PedidoItem.fromMap(Map<String, dynamic>.from(elemento)),
          );
        }
      }
    }

    final costoEnvio = _toDouble(map['costoEnvio'], defaultValue: 0.0);
    final rawBorrador = map['borradorFactura'];
    final borrador = rawBorrador is Map<String, dynamic>
        ? BorradorFacturaPedido.fromMap(rawBorrador)
        : (rawBorrador is Map
              ? BorradorFacturaPedido.fromMap(
                  Map<String, dynamic>.from(rawBorrador),
                )
              : BorradorFacturaPedido(costoEnvio: costoEnvio));

    final rawKeywords = map['keywordsBusqueda'];
    List<String>? keywordsParseadas;
    if (rawKeywords is List) {
      keywordsParseadas = rawKeywords
          .map((e) => normalizarTextoBusqueda(e.toString()))
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    return Pedido(
      id: id ?? (map['id'] ?? '').toString(),
      numeroPedido: (map['numeroPedido'] ?? '').toString(),
      clienteId: (map['clienteId'] ?? '').toString(),
      clienteNombre: (map['clienteNombre'] ?? '').toString(),
      clienteTelefono: (map['clienteTelefono'] ?? '').toString(),
      clienteDireccion: (map['clienteDireccion'] ?? '').toString(),
      clienteDepartamento: (map['clienteDepartamento'] ?? '').toString(),
      items: itemsParseados,
      keywordsBusqueda: keywordsParseadas,
      estadoEnvio: EstadoEnvioPedido.fromValor(map['estadoEnvio'] as String?),
      costoEnvio: costoEnvio,
      borradorFactura: borrador,
      facturado: map['facturado'] == true,
      ventaId: map['ventaId'] as String?,
      facturaNumero: map['facturaNumero'] as String?,
      fechaPrevistaEntrega: _parseFechaPrevista(map['fechaPrevistaEntrega']),
      fechaEnvio: _toDateTime(map['fechaEnvio']),
      fechaEntrega: _toDateTime(map['fechaEntrega']),
      fechaFacturacion: _toDateTime(map['fechaFacturacion']),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }
}
