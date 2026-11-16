import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/pedido.dart';
import '../models/venta.dart';

/// Categorías de error controladas al registrar un pedido en Firestore.
enum TipoErrorPedido {
  datosInvalidos,
  pedidoExistente,
  pedidoNoEncontrado,
  conflictoConcurrencia,
  actualizacionConfirmadaSinRecarga,
  permisosInsuficientes,
  errorConexion,
  errorTransaccion,
}

/// Excepción tipada emitida por [PedidoController] ante fallos de validación,
/// concurrencia, permisos o conexión.
class PedidoControllerException implements Exception {
  final TipoErrorPedido tipo;
  final String mensaje;
  final String? codigoFirebase;

  const PedidoControllerException({
    required this.tipo,
    required this.mensaje,
    this.codigoFirebase,
  });

  @override
  String toString() =>
      'PedidoControllerException(${tipo.name}): $mensaje'
      '${codigoFirebase != null ? ' [$codigoFirebase]' : ''}';
}

/// Controlador para la gestión transaccional de pedidos en Firestore.
class PedidoController {
  static const String collection = 'pedidos';
  static const String contadoresCollection = 'contadores';
  static const String contadorDocId = 'pedidos';
  static const String contadorFacturasDocId = 'facturas';

  /// Formatea un consecutivo entero positivo al formato oficial `PED-0001`.
  ///
  /// Lanza [ArgumentError] si [numero] es menor que 1.
  static String formatearNumeroPedido(int numero) {
    if (numero < 1) {
      throw ArgumentError.value(
        numero,
        'numero',
        'El consecutivo del pedido debe ser mayor o igual a 1.',
      );
    }

    if (numero < 1000) {
      return 'PED-${numero.toString().padLeft(4, '0')}';
    }
    return 'PED-$numero';
  }

  /// Formatea un consecutivo entero positivo al formato oficial `FAC-0001`.
  ///
  /// Lanza [ArgumentError] si [numero] es menor que 1.
  static String formatearNumeroFactura(int numero) {
    if (numero < 1) {
      throw ArgumentError.value(
        numero,
        'numero',
        'El consecutivo de la factura debe ser mayor o igual a 1.',
      );
    }

    if (numero < 1000) {
      return 'FAC-${numero.toString().padLeft(4, '0')}';
    }
    return 'FAC-$numero';
  }

  /// Valida que el borrador cumpla todas las reglas previas de un pedido nuevo.
  static void validarBorradorParaCreacion(Pedido borrador, {String? pedidoId}) {
    if (pedidoId != null && pedidoId.trim().isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador del pedido no puede estar vacío.',
      );
    }

    if (borrador.clienteId.trim().isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El pedido debe estar asociado a un cliente válido.',
      );
    }

    if (borrador.clienteNombre.trim().isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El nombre del cliente es obligatorio.',
      );
    }

    if (borrador.items.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El pedido debe incluir al menos un producto.',
      );
    }

    for (final item in borrador.items) {
      if (item.itemId.trim().isEmpty ||
          item.productoId.trim().isEmpty ||
          item.nombre.trim().isEmpty) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.datosInvalidos,
          mensaje:
              'Cada producto del pedido debe tener identificador y nombre.',
        );
      }

      if (item.cantidad < 1) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.datosInvalidos,
          mensaje: 'La cantidad de cada producto debe ser al menos 1.',
        );
      }

      if (!item.precioUnitario.isFinite || item.precioUnitario < 0) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.datosInvalidos,
          mensaje: 'El precio unitario debe ser un monto válido no negativo.',
        );
      }
    }

    if (!borrador.costoEnvio.isFinite || borrador.costoEnvio < 0) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El costo de envío debe ser un monto válido no negativo.',
      );
    }

    final factura = borrador.borradorFactura;
    if (!factura.impuestoPorcentaje.isFinite ||
        factura.impuestoPorcentaje < 0) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'El porcentaje de impuesto debe ser un valor válido no negativo.',
      );
    }

    if (!factura.descuentoPorcentaje.isFinite ||
        factura.descuentoPorcentaje < 0 ||
        factura.descuentoPorcentaje > 100) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El porcentaje de descuento debe estar entre 0 y 100.',
      );
    }

    if (!factura.costoEnvio.isFinite || factura.costoEnvio < 0) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El envío del borrador debe ser un monto válido no negativo.',
      );
    }

    if (borrador.numeroPedido.trim().isNotEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'Un pedido nuevo no debe tener número asignado previamente.',
      );
    }

    if (borrador.facturado ||
        borrador.ventaId != null ||
        borrador.facturaNumero != null ||
        borrador.fechaFacturacion != null) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'Un pedido nuevo no puede crearse ya facturado ni con venta.',
      );
    }

    if (borrador.createdAt != null || borrador.updatedAt != null) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'Las fechas de creación y actualización las asigna el servidor.',
      );
    }
  }

  /// Construye el [Pedido] definitivo con [id] y [numeroPedido], regenerando
  /// [keywordsBusqueda] sin alterar los importes ni el borrador de factura.
  static Pedido construirPedidoDefinitivo({
    required Pedido borrador,
    required String id,
    required String numeroPedido,
  }) {
    return Pedido(
      id: id,
      numeroPedido: numeroPedido,
      clienteId: borrador.clienteId.trim(),
      clienteNombre: borrador.clienteNombre.trim(),
      clienteTelefono: borrador.clienteTelefono.trim(),
      clienteDireccion: borrador.clienteDireccion.trim(),
      clienteDepartamento: borrador.clienteDepartamento.trim(),
      items: borrador.items,
      estadoEnvio: borrador.estadoEnvio,
      costoEnvio: borrador.costoEnvio,
      borradorFactura: borrador.borradorFactura,
      facturado: false,
      ventaId: null,
      facturaNumero: null,
      fechaPrevistaEntrega: borrador.fechaPrevistaEntrega,
      fechaEnvio: borrador.fechaEnvio,
      fechaEntrega: borrador.fechaEntrega,
      fechaFacturacion: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  /// Registra un pedido nuevo en Firestore asignando de forma atómica su
  /// consecutivo único en `contadores/pedidos`.
  ///
  /// No crea ventas, recibos ni PDF, ni modifica el inventario.
  static Future<Pedido> crearPedido(
    Pedido borrador, {
    FirebaseFirestore? firestore,
    String? pedidoId,
  }) async {
    debugPrint('[PEDIDO_CONTROLLER] 1. Entrada a crearPedido');
    validarBorradorParaCreacion(borrador, pedidoId: pedidoId);
    debugPrint('[PEDIDO_CONTROLLER] 2. Validaciones completadas');

    final db = firestore ?? FirebaseFirestore.instance;
    final idNormalizado = pedidoId?.trim();
    final pedidoRef = idNormalizado != null
        ? db.collection(collection).doc(idNormalizado)
        : db.collection(collection).doc();
    final contadorRef = db.collection(contadoresCollection).doc(contadorDocId);

    try {
      debugPrint(
        '[PEDIDO_CONTROLLER] 3. Antes de llamar a runTransaction (pedidoId=${pedidoRef.id})',
      );
      final pedidoCreado = await db.runTransaction<Pedido>((tx) async {
        debugPrint('[PEDIDO_CONTROLLER] 4. Entrada al callback de runTransaction');

        // 1. Todas las lecturas deben ocurrir antes de cualquier escritura.
        debugPrint(
          '[PEDIDO_CONTROLLER] 5a. Antes de tx.get(pedidoRef) (${pedidoRef.id})',
        );
        final pedidoExistente = await tx.get(pedidoRef);
        debugPrint(
          '[PEDIDO_CONTROLLER] 5b. Después de tx.get(pedidoRef) (exists=${pedidoExistente.exists})',
        );
        if (pedidoExistente.exists) {
          throw PedidoControllerException(
            tipo: TipoErrorPedido.pedidoExistente,
            mensaje:
                'Ya existe un pedido registrado con el ID ${pedidoRef.id}.',
          );
        }

        debugPrint('[PEDIDO_CONTROLLER] 5c. Antes de tx.get(contadorRef)');
        final contadorSnap = await tx.get(contadorRef);
        debugPrint(
          '[PEDIDO_CONTROLLER] 5d. Después de tx.get(contadorRef) (exists=${contadorSnap.exists})',
        );

        final int siguienteNumero;
        final bool contadorExiste = contadorSnap.exists;

        if (!contadorExiste) {
          siguienteNumero = 1;
        } else {
          final rawUltimo = contadorSnap.data()?['ultimoNumero'];
          if (rawUltimo is! int || rawUltimo < 1) {
            throw const PedidoControllerException(
              tipo: TipoErrorPedido.errorTransaccion,
              mensaje:
                  'El contador de pedidos tiene un formato inválido en Firestore.',
            );
          }
          siguienteNumero = rawUltimo + 1;
        }

        final numeroPedido = formatearNumeroPedido(siguienteNumero);
        final pedidoDefinitivo = construirPedidoDefinitivo(
          borrador: borrador,
          id: pedidoRef.id,
          numeroPedido: numeroPedido,
        );

        // 2. Escrituras atómicas: pedido nuevo + avance del contador.
        debugPrint(
          '[PEDIDO_CONTROLLER] 6a. Antes de preparar escrituras en tx (numeroPedido=$numeroPedido, contadorExiste=$contadorExiste)',
        );
        tx.set(
          pedidoRef,
          pedidoDefinitivo.toMap(incluirMarcadoresServidor: true),
        );

        if (!contadorExiste) {
          tx.set(contadorRef, {
            'ultimoNumero': 1,
            'ultimoPedidoId': pedidoRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.update(contadorRef, {
            'ultimoNumero': siguienteNumero,
            'ultimoPedidoId': pedidoRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        debugPrint(
          '[PEDIDO_CONTROLLER] 6b. Después de preparar escrituras en tx',
        );

        debugPrint(
          '[PEDIDO_CONTROLLER] 7. Antes de salir del callback de runTransaction',
        );
        return pedidoDefinitivo;
      });
      debugPrint('[PEDIDO_CONTROLLER] 8. Después de finalizar runTransaction');

      // Leer el documento confirmado para devolver las marcas temporales reales
      // asignadas por el servidor sin inventar fechas locales.
      try {
        debugPrint(
          '[PEDIDO_CONTROLLER] 9a. Antes de lectura final pedidoRef.get() (${pedidoRef.id})',
        );
        final confirmadoSnap = await pedidoRef.get();
        debugPrint(
          '[PEDIDO_CONTROLLER] 9b. Después de lectura final pedidoRef.get() (exists=${confirmadoSnap.exists})',
        );
        final data = confirmadoSnap.data();
        if (confirmadoSnap.exists && data != null) {
          return Pedido.fromMap(data, id: confirmadoSnap.id);
        }
      } catch (_) {
        // Si la lectura posterior falla tras confirmar la transacción, se
        // devuelve el pedido ya asignado sin ocultar que se guardó en servidor.
      }

      return pedidoCreado;
    } on PedidoControllerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapearFirebaseException(e);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudo completar la creación del pedido: $e',
      );
    }
  }

  /// Consulta los pedidos almacenados en Firestore ordenados del más reciente
  /// al más antiguo por `createdAt`.
  static Future<List<Pedido>> cargarPedidos({
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;

    try {
      final snapshot = await db
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Pedido.fromMap(doc.data(), id: doc.id))
          .toList();
    } on PedidoControllerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapearFirebaseException(e, esLectura: true);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudieron consultar los pedidos en Firestore: $e',
      );
    }
  }

  /// Recupera en solo lectura el pedido asociado a [facturaId], buscando primero
  /// por `facturaNumero` y, si no existe coincidencia, por `ventaId`.
  static Future<Pedido?> cargarPedidoPorFactura(
    String facturaId, {
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = facturaId.trim();
    if (idLimpio.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador de la factura no puede estar vacío.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;

    try {
      final porFacturaNumero = await db
          .collection(collection)
          .where('facturaNumero', isEqualTo: idLimpio)
          .limit(1)
          .get();

      if (porFacturaNumero.docs.isNotEmpty) {
        final doc = porFacturaNumero.docs.first;
        return Pedido.fromMap(doc.data(), id: doc.id);
      }

      final porVentaId = await db
          .collection(collection)
          .where('ventaId', isEqualTo: idLimpio)
          .limit(1)
          .get();

      if (porVentaId.docs.isNotEmpty) {
        final doc = porVentaId.docs.first;
        return Pedido.fromMap(doc.data(), id: doc.id);
      }

      return null;
    } on PedidoControllerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapearFirebaseException(e, esLectura: true);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudo consultar el pedido por factura en Firestore: $e',
      );
    }
  }

  /// Actualiza en una sola transacción de Firestore los estados de elaboración
  /// de los accesorios indicados en [estadosPorItemId], verificando control de
  /// concurrencia optimista mediante [updatedAtEsperado].
  static Future<Pedido> actualizarEstadosProduccion({
    required String pedidoId,
    required Map<String, EstadoElaboracionPedido> estadosPorItemId,
    DateTime? updatedAtEsperado,
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = pedidoId.trim();
    if (idLimpio.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador del pedido es obligatorio.',
      );
    }

    for (final itemId in estadosPorItemId.keys) {
      if (itemId.trim().isEmpty) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.datosInvalidos,
          mensaje: 'Cada accesorio a actualizar debe tener un itemId válido.',
        );
      }
    }

    if (estadosPorItemId.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'Debes indicar al menos un accesorio para actualizar.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final pedidoRef = db.collection(collection).doc(idLimpio);

    try {
      final resultado = await db.runTransaction<({Pedido pedido, bool escrito})>(
        (tx) async {
          final snapshot = await tx.get(pedidoRef);
          final data = snapshot.data();

          if (!snapshot.exists || data == null) {
            throw const PedidoControllerException(
              tipo: TipoErrorPedido.pedidoNoEncontrado,
              mensaje: 'El pedido no existe o fue eliminado de Firestore.',
            );
          }

          final pedidoActual = Pedido.fromMap(data, id: snapshot.id);
          final marcaActual =
              pedidoActual.updatedAt?.toUtc().microsecondsSinceEpoch;
          final marcaEsperada =
              updatedAtEsperado?.toUtc().microsecondsSinceEpoch;

          if (marcaActual != marcaEsperada) {
            throw const PedidoControllerException(
              tipo: TipoErrorPedido.conflictoConcurrencia,
              mensaje:
                  'Este pedido fue modificado por otro administrador. Actualiza la lista antes de guardar.',
            );
          }

          final idsExistentes =
              pedidoActual.items.map((item) => item.itemId).toSet();
          for (final itemId in estadosPorItemId.keys) {
            if (!idsExistentes.contains(itemId)) {
              throw PedidoControllerException(
                tipo: TipoErrorPedido.datosInvalidos,
                mensaje:
                    'No se encontró el accesorio "$itemId" dentro del pedido.',
              );
            }
          }

          var huboCambioReal = false;
          final itemsActualizados = <PedidoItem>[];
          for (final item in pedidoActual.items) {
            final nuevoEstado = estadosPorItemId[item.itemId];
            if (nuevoEstado != null && nuevoEstado != item.estadoElaboracion) {
              huboCambioReal = true;
              itemsActualizados.add(
                item.copyWith(estadoElaboracion: nuevoEstado),
              );
            } else {
              itemsActualizados.add(item);
            }
          }

          if (!huboCambioReal) {
            return (pedido: pedidoActual, escrito: false);
          }

          final pedidoActualizado = pedidoActual.copyWith(
            items: itemsActualizados,
          );

          tx.update(pedidoRef, {
            'items': itemsActualizados.map((item) => item.toMap()).toList(),
            'estadoProduccion':
                pedidoActualizado.estadoProduccion.valorFirestore,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return (pedido: pedidoActualizado, escrito: true);
        },
      );

      if (!resultado.escrito) {
        return resultado.pedido;
      }

      try {
        final confirmadoSnap = await pedidoRef.get();
        final data = confirmadoSnap.data();
        if (confirmadoSnap.exists && data != null) {
          return Pedido.fromMap(data, id: confirmadoSnap.id);
        }
      } on FirebaseException catch (e) {
        throw PedidoControllerException(
          tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
          mensaje:
              'Los cambios se guardaron en Firestore, pero no se pudo recuperar la versión actualizada del pedido. Recarga el pedido antes de continuar editando.',
          codigoFirebase: e.code,
        );
      } catch (_) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
          mensaje:
              'Los cambios se guardaron en Firestore, pero no se pudo recuperar la versión actualizada del pedido. Recarga el pedido antes de continuar editando.',
        );
      }

      throw const PedidoControllerException(
        tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
        mensaje:
            'Los cambios se guardaron en Firestore, pero el documento actualizado no pudo recuperarse. Recarga el pedido antes de continuar editando.',
      );
    } on PedidoControllerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapearFirebaseException(e, esActualizacion: true);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudieron actualizar los estados de producción: $e',
      );
    }
  }

  /// Normaliza una fecha seleccionada al mediodía de Honduras (`18:00:00Z` UTC),
  /// conservando su día calendario sin corrimientos por zona horaria.
  static DateTime normalizarFechaPrevistaEntrega(DateTime fecha) {
    if (fecha.year < 2000 || fecha.year > 2100) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'La fecha prevista de entrega debe estar entre los años 2000 y 2100.',
      );
    }
    return DateTime.utc(fecha.year, fecha.month, fecha.day, 18);
  }

  /// Actualiza en una sola transacción de Firestore la [nuevaFechaPrevistaEntrega]
  /// de un pedido existente, validando concurrencia optimista con
  /// [updatedAtEsperado] y rechazando pedidos facturados o vinculados a venta.
  static Future<Pedido> actualizarFechaPrevistaEntrega({
    required String pedidoId,
    required DateTime? nuevaFechaPrevistaEntrega,
    DateTime? updatedAtEsperado,
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = pedidoId.trim();
    if (idLimpio.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador del pedido es obligatorio.',
      );
    }
    if (nuevaFechaPrevistaEntrega == null) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'Debes seleccionar una fecha prevista de entrega válida.',
      );
    }

    final fechaNormalizada = normalizarFechaPrevistaEntrega(
      nuevaFechaPrevistaEntrega,
    );

    final db = firestore ?? FirebaseFirestore.instance;
    final pedidoRef = db.collection(collection).doc(idLimpio);

    try {
      final resultado = await db.runTransaction<({Pedido pedido, bool escrito})>(
        (tx) async {
          final snapshot = await tx.get(pedidoRef);
          final data = snapshot.data();

          if (!snapshot.exists || data == null) {
            throw const PedidoControllerException(
              tipo: TipoErrorPedido.pedidoNoEncontrado,
              mensaje: 'El pedido no existe o fue eliminado de Firestore.',
            );
          }

          final pedidoActual = Pedido.fromMap(data, id: snapshot.id);
          final marcaActual =
              pedidoActual.updatedAt?.toUtc().microsecondsSinceEpoch;
          final marcaEsperada =
              updatedAtEsperado?.toUtc().microsecondsSinceEpoch;

          if (marcaActual != marcaEsperada) {
            throw const PedidoControllerException(
              tipo: TipoErrorPedido.conflictoConcurrencia,
              mensaje:
                  'Este pedido fue modificado por otro administrador. Actualiza la lista antes de guardar.',
            );
          }

          if (pedidoActual.facturado || pedidoActual.ventaId != null) {
            throw const PedidoControllerException(
              tipo: TipoErrorPedido.datosInvalidos,
              mensaje:
                  'No se puede modificar la fecha de entrega de un pedido ya facturado.',
            );
          }

          final fechaActual = pedidoActual.fechaPrevistaEntrega;
          final sinCambios =
              fechaActual != null &&
              fechaActual.year == fechaNormalizada.year &&
              fechaActual.month == fechaNormalizada.month &&
              fechaActual.day == fechaNormalizada.day;

          if (sinCambios) {
            return (pedido: pedidoActual, escrito: false);
          }

          final pedidoActualizado = pedidoActual.copyWith(
            fechaPrevistaEntrega: fechaNormalizada,
          );

          tx.update(pedidoRef, {
            'fechaPrevistaEntrega': Timestamp.fromDate(fechaNormalizada),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return (pedido: pedidoActualizado, escrito: true);
        },
      );

      if (!resultado.escrito) {
        return resultado.pedido;
      }

      try {
        final confirmadoSnap = await pedidoRef.get();
        final data = confirmadoSnap.data();
        if (confirmadoSnap.exists && data != null) {
          return Pedido.fromMap(data, id: confirmadoSnap.id);
        }
      } on FirebaseException catch (e) {
        throw PedidoControllerException(
          tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
          mensaje:
              'La fecha de entrega se guardó en Firestore, pero no se pudo recuperar la versión actualizada del pedido. Recarga el pedido antes de continuar editando.',
          codigoFirebase: e.code,
        );
      } catch (_) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
          mensaje:
              'La fecha de entrega se guardó en Firestore, pero no se pudo recuperar la versión actualizada del pedido. Recarga el pedido antes de continuar editando.',
        );
      }

      throw const PedidoControllerException(
        tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
        mensaje:
            'La fecha de entrega se guardó en Firestore, pero el documento actualizado no pudo recuperarse. Recarga el pedido antes de continuar editando.',
      );
    } on PedidoControllerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapearFirebaseException(e, esActualizacion: true);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudo actualizar la fecha prevista de entrega: $e',
      );
    }
  }

  /// Filtra la lista original de mapas de Firestore conservando intactos los
  /// accesorios restantes (sin reconvertirlos mediante `PedidoItem.fromMap` y
  /// `toMap`), exigiendo una coincidencia única de [itemId] y al menos un
  /// accesorio restante.
  @visibleForTesting
  static List<Map<dynamic, dynamic>> filtrarItemsOriginalesSinAccesorio({
    required dynamic rawItems,
    required String itemId,
  }) {
    if (rawItems is! List) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'La lista de accesorios del pedido tiene un formato inválido en Firestore.',
      );
    }

    var coincidencias = 0;
    final itemsRestantes = <Map<dynamic, dynamic>>[];

    for (final entry in rawItems) {
      if (entry is! Map) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.datosInvalidos,
          mensaje:
              'Uno de los accesorios del pedido tiene un formato inválido en Firestore.',
        );
      }

      final entryItemId = (entry['itemId'] ?? '').toString();
      if (entryItemId == itemId) {
        coincidencias++;
      } else {
        itemsRestantes.add(entry);
      }
    }

    if (coincidencias == 0) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'No se encontró el accesorio "$itemId" dentro del pedido.',
      );
    }
    if (coincidencias > 1) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'El identificador "$itemId" es ambiguo porque aparece más de una vez en el pedido.',
      );
    }
    if (rawItems.length <= 1) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'No se puede eliminar el último accesorio del pedido. Para anularlo por completo, cancela o elimina el pedido en una etapa posterior.',
      );
    }

    return itemsRestantes;
  }

  /// Elimina un accesorio específico identificado por [itemId] de un pedido
  /// existente en Firestore mediante una transacción, recalculando
  /// [estadoProduccion], [borradorFactura] y [keywordsBusqueda] sin alterar
  /// los demás accesorios ni los parámetros comerciales.
  static Future<Pedido> eliminarAccesorioPedido({
    required String pedidoId,
    required String itemId,
    required DateTime? updatedAtEsperado,
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = pedidoId.trim();
    if (idLimpio.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador del pedido es obligatorio.',
      );
    }

    final itemIdLimpio = itemId.trim();
    if (itemIdLimpio.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador del accesorio es obligatorio.',
      );
    }

    if (updatedAtEsperado == null) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'Se requiere la versión actual del pedido (updatedAt) para eliminar un accesorio de forma segura.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final pedidoRef = db.collection(collection).doc(idLimpio);

    try {
      await db.runTransaction<void>((tx) async {
        final snapshot = await tx.get(pedidoRef);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw const PedidoControllerException(
            tipo: TipoErrorPedido.pedidoNoEncontrado,
            mensaje: 'El pedido no existe o fue eliminado de Firestore.',
          );
        }

        final pedidoActual = Pedido.fromMap(data, id: snapshot.id);
        final marcaActual =
            pedidoActual.updatedAt?.toUtc().microsecondsSinceEpoch;
        final marcaEsperada = updatedAtEsperado.toUtc().microsecondsSinceEpoch;

        if (marcaActual != marcaEsperada) {
          throw const PedidoControllerException(
            tipo: TipoErrorPedido.conflictoConcurrencia,
            mensaje:
                'Este pedido fue modificado por otro administrador. Recárgalo antes de continuar.',
          );
        }

        if (pedidoActual.facturado || pedidoActual.ventaId != null) {
          throw const PedidoControllerException(
            tipo: TipoErrorPedido.datosInvalidos,
            mensaje:
                'No se puede quitar un accesorio de un pedido ya facturado.',
          );
        }

        final itemsRestantesRaw = filtrarItemsOriginalesSinAccesorio(
          rawItems: data['items'],
          itemId: itemIdLimpio,
        );

        final nuevosItems = pedidoActual.items
            .where((item) => item.itemId != itemIdLimpio)
            .toList(growable: false);

        final pedidoActualizado = pedidoActual.copyWith(items: nuevosItems);
        final nuevoSubtotal = pedidoActualizado.subtotalProductos;

        tx.update(pedidoRef, {
          'items': itemsRestantesRaw,
          'estadoProduccion': pedidoActualizado.estadoProduccion.valorFirestore,
          'borradorFactura': pedidoActualizado.borradorFactura.toMap(
            subtotalProductos: nuevoSubtotal,
          ),
          'keywordsBusqueda': pedidoActualizado.keywordsBusqueda,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      try {
        final confirmadoSnap = await pedidoRef.get();
        final data = confirmadoSnap.data();
        if (confirmadoSnap.exists && data != null) {
          return Pedido.fromMap(data, id: confirmadoSnap.id);
        }
      } on FirebaseException catch (e) {
        throw PedidoControllerException(
          tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
          mensaje:
              'El accesorio se eliminó en Firestore, pero no se pudo recuperar la versión actualizada del pedido. Recarga el pedido antes de continuar editando.',
          codigoFirebase: e.code,
        );
      } catch (_) {
        throw const PedidoControllerException(
          tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
          mensaje:
              'El accesorio se eliminó en Firestore, pero no se pudo recuperar la versión actualizada del pedido. Recarga el pedido antes de continuar editando.',
        );
      }

      throw const PedidoControllerException(
        tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
        mensaje:
            'El accesorio se eliminó en Firestore, pero el documento actualizado no pudo recuperarse. Recarga el pedido antes de continuar editando.',
      );
    } on PedidoControllerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapearFirebaseException(e, esActualizacion: true);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudo eliminar el accesorio del pedido: $e',
      );
    }
  }

  /// Elimina definitivamente un documento de `pedidos` en Firestore mediante una
  /// transacción, verificando control de concurrencia con [updatedAtEsperado] y
  /// rechazando pedidos ya facturados o vinculados a una venta.
  static Future<void> eliminarPedido({
    required String pedidoId,
    required DateTime? updatedAtEsperado,
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = pedidoId.trim();
    if (idLimpio.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador del pedido es obligatorio.',
      );
    }

    if (updatedAtEsperado == null) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'Se requiere la versión actual del pedido (updatedAt) para eliminarlo de forma segura.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final pedidoRef = db.collection(collection).doc(idLimpio);

    try {
      await db.runTransaction<void>((tx) async {
        final snapshot = await tx.get(pedidoRef);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw const PedidoControllerException(
            tipo: TipoErrorPedido.pedidoNoEncontrado,
            mensaje: 'El pedido no existe o ya fue eliminado de Firestore.',
          );
        }

        final pedidoActual = Pedido.fromMap(data, id: snapshot.id);
        final marcaActual =
            pedidoActual.updatedAt?.toUtc().microsecondsSinceEpoch;
        final marcaEsperada = updatedAtEsperado.toUtc().microsecondsSinceEpoch;

        if (marcaActual != marcaEsperada) {
          throw const PedidoControllerException(
            tipo: TipoErrorPedido.conflictoConcurrencia,
            mensaje:
                'Este pedido fue modificado por otro administrador. Recárgalo antes de continuar.',
          );
        }

        if (pedidoActual.facturado ||
            pedidoActual.ventaId != null ||
            pedidoActual.facturaNumero != null) {
          throw const PedidoControllerException(
            tipo: TipoErrorPedido.datosInvalidos,
            mensaje:
                'No se puede eliminar un pedido ya facturado o vinculado a una venta.',
          );
        }

        tx.delete(pedidoRef);
      });
    } on PedidoControllerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapearFirebaseException(e, esActualizacion: true);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudo eliminar el pedido: $e',
      );
    }
  }

  /// Construye la instancia de [Venta] correspondiente a [pedido] reutilizando
  /// los cálculos centralizados de [BorradorFacturaPedido].
  @visibleForTesting
  static Venta construirVentaParaPedido({
    required Pedido pedido,
    required String facturaNumero,
    DateTime? fechaEmision,
  }) {
    final subtotal = pedido.subtotalProductos;
    final borrador = pedido.borradorFactura;
    final descuentoMonto = borrador.calcularDescuentoMonto(subtotal);
    final impuesto = borrador.calcularImpuestoMonto(subtotal);
    final total = borrador.calcularTotal(subtotal);

    return Venta(
      id: facturaNumero,
      clienteId: pedido.clienteId.trim(),
      clienteNombre: pedido.clienteNombre.trim(),
      fecha: fechaEmision ?? DateTime.now(),
      subtotal: subtotal,
      impuesto: impuesto,
      total: total,
      envio: borrador.costoEnvio,
      descuentoMayoristaActivo: borrador.descuentoMayoristaActivo,
      descuentoPorcentaje: borrador.descuentoPorcentaje,
      descuentoMonto: descuentoMonto,
    );
  }

  /// Factura un pedido terminado en una única transacción atómica en servidor
  /// mediante la Cloud Function `facturarPedido` (región `us-central1`) y
  /// recarga el documento actualizado del pedido desde Firestore.
  static Future<Pedido> facturarPedido({
    required String pedidoId,
    required DateTime? updatedAtEsperado,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) async {
    final idLimpio = pedidoId.trim();
    if (idLimpio.isEmpty) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje: 'El identificador del pedido es obligatorio.',
      );
    }

    if (updatedAtEsperado == null) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.datosInvalidos,
        mensaje:
            'Se requiere la versión actual del pedido (updatedAt) para facturar de forma segura.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final pedidoRef = db.collection(collection).doc(idLimpio);
    final fnClient =
        functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

    try {
      final callable = fnClient.httpsCallable('facturarPedido');
      await callable.call<dynamic>(<String, dynamic>{
        'pedidoId': idLimpio,
        'updatedAtEsperadoMs': updatedAtEsperado.toUtc().millisecondsSinceEpoch,
      });
    } on PedidoControllerException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw _mapearFirebaseFunctionsException(e);
    } catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.errorTransaccion,
        mensaje: 'No se pudo facturar el pedido: $e',
      );
    }

    try {
      final confirmadoSnap = await pedidoRef.get();
      final data = confirmadoSnap.data();
      if (confirmadoSnap.exists && data != null) {
        return Pedido.fromMap(data, id: confirmadoSnap.id);
      }
    } on FirebaseException catch (e) {
      throw PedidoControllerException(
        tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
        mensaje:
            'La factura se emitió en Firestore, pero no se pudo recuperar el pedido actualizado. Recarga el pedido para confirmar el número de factura.',
        codigoFirebase: e.code,
      );
    } catch (_) {
      throw const PedidoControllerException(
        tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
        mensaje:
            'La factura se emitió en Firestore, pero no se pudo recuperar el pedido actualizado. Recarga el pedido para confirmar el número de factura.',
      );
    }

    throw const PedidoControllerException(
      tipo: TipoErrorPedido.actualizacionConfirmadaSinRecarga,
      mensaje:
          'La factura se emitió en Firestore, pero el documento actualizado no pudo recuperarse. Recarga el pedido para confirmar el número de factura.',
    );
  }

  static PedidoControllerException _mapearFirebaseFunctionsException(
    FirebaseFunctionsException e,
  ) {
    final mensajeServidor = e.message?.trim();
    final tieneMensaje = mensajeServidor != null && mensajeServidor.isNotEmpty;

    switch (e.code) {
      case 'unauthenticated':
      case 'permission-denied':
        return PedidoControllerException(
          tipo: TipoErrorPedido.permisosInsuficientes,
          mensaje: tieneMensaje
              ? mensajeServidor
              : 'No tienes permisos suficientes para facturar pedidos.',
          codigoFirebase: e.code,
        );
      case 'not-found':
        return PedidoControllerException(
          tipo: TipoErrorPedido.pedidoNoEncontrado,
          mensaje: tieneMensaje
              ? mensajeServidor
              : 'El pedido no existe o fue eliminado de Firestore.',
          codigoFirebase: e.code,
        );
      case 'invalid-argument':
        return PedidoControllerException(
          tipo: TipoErrorPedido.datosInvalidos,
          mensaje: tieneMensaje
              ? mensajeServidor
              : 'Los datos enviados para facturar el pedido no son válidos.',
          codigoFirebase: e.code,
        );
      case 'failed-precondition':
        final esConcurrencia = (mensajeServidor ?? '')
            .toLowerCase()
            .contains('modificado por otro administrador');
        return PedidoControllerException(
          tipo: esConcurrencia
              ? TipoErrorPedido.conflictoConcurrencia
              : TipoErrorPedido.datosInvalidos,
          mensaje: tieneMensaje
              ? mensajeServidor
              : 'El pedido no cumple las condiciones requeridas para facturarse.',
          codigoFirebase: e.code,
        );
      case 'aborted':
        return PedidoControllerException(
          tipo: TipoErrorPedido.conflictoConcurrencia,
          mensaje: tieneMensaje
              ? mensajeServidor
              : 'Este pedido fue modificado por otro administrador. Recárgalo antes de facturar.',
          codigoFirebase: e.code,
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return PedidoControllerException(
          tipo: TipoErrorPedido.errorConexion,
          mensaje:
              'Error de conexión al intentar facturar el pedido. Verifica tu internet e inténtalo nuevamente.',
          codigoFirebase: e.code,
        );
      default:
        return PedidoControllerException(
          tipo: TipoErrorPedido.errorTransaccion,
          mensaje: tieneMensaje
              ? mensajeServidor
              : 'No se pudo completar la facturación en el servidor.',
          codigoFirebase: e.code,
        );
    }
  }

  static PedidoControllerException _mapearFirebaseException(
    FirebaseException e, {
    bool esLectura = false,
    bool esActualizacion = false,
  }) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return PedidoControllerException(
          tipo: TipoErrorPedido.permisosInsuficientes,
          mensaje: esLectura
              ? 'No tienes permisos suficientes para consultar pedidos en Firestore.'
              : (esActualizacion
                    ? 'No tienes permisos suficientes para actualizar pedidos en Firestore.'
                    : 'No tienes permisos suficientes para registrar pedidos en Firestore.'),
          codigoFirebase: e.code,
        );
      case 'already-exists':
        return PedidoControllerException(
          tipo: TipoErrorPedido.pedidoExistente,
          mensaje: 'El pedido ya existe en Firestore.',
          codigoFirebase: e.code,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return PedidoControllerException(
          tipo: TipoErrorPedido.errorConexion,
          mensaje:
              'Error de conexión al comunicarse con Firestore. Intenta nuevamente.',
          codigoFirebase: e.code,
        );
      default:
        return PedidoControllerException(
          tipo: TipoErrorPedido.errorTransaccion,
          mensaje:
              e.message ??
              (esLectura
                  ? 'No se pudieron consultar los pedidos en Firestore.'
                  : (esActualizacion
                        ? 'Error de transacción al actualizar el pedido en Firestore.'
                        : 'Error de transacción al registrar el pedido en Firestore.')),
          codigoFirebase: e.code,
        );
    }
  }
}
