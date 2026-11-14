import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/pedido.dart';

/// Categorías de error controladas al registrar un pedido en Firestore.
enum TipoErrorPedido {
  datosInvalidos,
  pedidoExistente,
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

  static PedidoControllerException _mapearFirebaseException(
    FirebaseException e,
  ) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return PedidoControllerException(
          tipo: TipoErrorPedido.permisosInsuficientes,
          mensaje:
              'No tienes permisos suficientes para registrar pedidos en Firestore.',
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
              'Error de transacción al registrar el pedido en Firestore.',
          codigoFirebase: e.code,
        );
    }
  }
}
