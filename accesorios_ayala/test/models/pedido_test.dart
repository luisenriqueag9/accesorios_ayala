import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/models/pedido.dart';

void main() {
  group('Pedido y modelos asociados', () {
    test(
      'Pedido nuevo inicia no facturado, sin venta ni fechas de servidor',
      () {
        final item = PedidoItem(
          itemId: 'line-1',
          productoId: 'prod-1',
          nombre: 'Pulsera personalizada',
          cantidad: 2,
          precioUnitario: 250.0,
          notaPersonalizacion: 'Iniciales M.A.',
        );

        final pedido = Pedido(
          id: 'ped-1',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          clienteTelefono: '9999-0000',
          clienteDireccion: 'Col. Centro',
          clienteDepartamento: 'Cortés',
          items: [item],
          costoEnvio: 120.0,
        );

        expect(pedido.estadoProduccion, EstadoElaboracionPedido.recibido);
        expect(pedido.estadoEnvio, EstadoEnvioPedido.pendiente);
        expect(pedido.facturado, isFalse);
        expect(pedido.ventaId, isNull);
        expect(pedido.facturaNumero, isNull);
        expect(pedido.createdAt, isNull);
        expect(pedido.updatedAt, isNull);
        expect(pedido.subtotalProductos, 500.0);
        expect(pedido.totalEstimado, 620.0);
        expect(pedido.borradorFactura.costoEnvio, 120.0);
      },
    );

    test(
      'Calcula estado general de producción según estados de sus productos',
      () {
        final item1 = PedidoItem(
          itemId: 'line-1',
          productoId: 'prod-1',
          nombre: 'Arete',
          cantidad: 1,
          precioUnitario: 100.0,
          estadoElaboracion: EstadoElaboracionPedido.recibido,
        );
        final item2 = PedidoItem(
          itemId: 'line-2',
          productoId: 'prod-2',
          nombre: 'Collar',
          cantidad: 1,
          precioUnitario: 200.0,
          estadoElaboracion: EstadoElaboracionPedido.recibido,
        );

        final todosRecibidos = Pedido(
          id: 'ped-2',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          items: [item1, item2],
        );
        expect(
          todosRecibidos.estadoProduccion,
          EstadoElaboracionPedido.recibido,
        );

        final mixto = todosRecibidos.copyWith(
          items: [
            item1.copyWith(
              estadoElaboracion: EstadoElaboracionPedido.terminado,
            ),
            item2,
          ],
        );
        expect(mixto.estadoProduccion, EstadoElaboracionPedido.enProceso);

        final unoEnProceso = todosRecibidos.copyWith(
          items: [
            item1.copyWith(
              estadoElaboracion: EstadoElaboracionPedido.enProceso,
            ),
            item2.copyWith(
              estadoElaboracion: EstadoElaboracionPedido.terminado,
            ),
          ],
        );
        expect(
          unoEnProceso.estadoProduccion,
          EstadoElaboracionPedido.enProceso,
        );

        final todosTerminados = todosRecibidos.copyWith(
          items: [
            item1.copyWith(
              estadoElaboracion: EstadoElaboracionPedido.terminado,
            ),
            item2.copyWith(
              estadoElaboracion: EstadoElaboracionPedido.terminado,
            ),
          ],
        );
        expect(
          todosTerminados.estadoProduccion,
          EstadoElaboracionPedido.terminado,
        );
      },
    );

    test(
      'Serializa y deserializa correctamente manteniendo precios, notas e IDs',
      () {
        final fechaCreacion = DateTime(2026, 11, 13, 10, 30);
        final fechaActualizacion = DateTime(2026, 11, 13, 12, 0);

        final pedidoOriginal = Pedido(
          id: 'ped-3',
          clienteId: 'cli-2',
          clienteNombre: 'Carlos Mejía',
          clienteTelefono: '8888-1111',
          clienteDireccion: 'Barrio Abajo',
          clienteDepartamento: 'Francisco Morazán',
          items: [
            PedidoItem(
              itemId: 'item-a',
              productoId: 'prod-10',
              nombre: 'Anillo grabado',
              cantidad: 3,
              precioUnitario: 180.0,
              notaPersonalizacion: 'Talla 7',
              estadoElaboracion: EstadoElaboracionPedido.enProceso,
            ),
          ],
          estadoEnvio: EstadoEnvioPedido.enviado,
          costoEnvio: 150.0,
          borradorFactura: BorradorFacturaPedido(
            impuestoPorcentaje: 15.0,
            descuentoMayoristaActivo: true,
            descuentoPorcentaje: 10.0,
            costoEnvio: 150.0,
          ),
          createdAt: fechaCreacion,
          updatedAt: fechaActualizacion,
        );

        final mapa = pedidoOriginal.toMap();
        expect(mapa['estadoProduccion'], 'en_proceso');
        expect(mapa['estadoEnvio'], 'enviado');
        expect(mapa['facturado'], isFalse);
        expect(mapa['ventaId'], isNull);
        expect(mapa['facturaNumero'], isNull);

        final reconstruido = Pedido.fromMap(mapa, id: 'ped-3');
        expect(reconstruido.id, 'ped-3');
        expect(reconstruido.clienteNombre, 'Carlos Mejía');
        expect(reconstruido.items.length, 1);
        expect(reconstruido.items.first.itemId, 'item-a');
        expect(reconstruido.items.first.precioUnitario, 180.0);
        expect(reconstruido.items.first.notaPersonalizacion, 'Talla 7');
        expect(
          reconstruido.items.first.estadoElaboracion,
          EstadoElaboracionPedido.enProceso,
        );
        expect(
          reconstruido.estadoProduccion,
          EstadoElaboracionPedido.enProceso,
        );
        expect(reconstruido.estadoEnvio, EstadoEnvioPedido.enviado);
        expect(reconstruido.borradorFactura.descuentoMayoristaActivo, isTrue);
        expect(reconstruido.borradorFactura.descuentoPorcentaje, 10.0);
        expect(reconstruido.borradorFactura.impuestoPorcentaje, 15.0);
        expect(reconstruido.createdAt, fechaCreacion);
        expect(reconstruido.updatedAt, fechaActualizacion);
      },
    );

    test(
      'Usa FieldValue.serverTimestamp() cuando incluirMarcadoresServidor es true y fechas son null',
      () {
        final pedido = Pedido(
          id: 'ped-4',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
        );

        final mapa = pedido.toMap(incluirMarcadoresServidor: true);
        expect(mapa['createdAt'], isA<FieldValue>());
        expect(mapa['updatedAt'], isA<FieldValue>());
      },
    );

    test('Rechaza cantidades menores que 1 e importes negativos', () {
      expect(
        () => PedidoItem(
          itemId: 'l1',
          productoId: 'p1',
          nombre: 'Pulsera',
          cantidad: 0,
          precioUnitario: 100.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => PedidoItem(
          itemId: 'l1',
          productoId: 'p1',
          nombre: 'Pulsera',
          cantidad: 1,
          precioUnitario: -10.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => Pedido(
          id: 'ped-inv',
          clienteId: 'cli-1',
          clienteNombre: 'Ana',
          costoEnvio: -5.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => BorradorFacturaPedido(impuestoPorcentaje: -1.0),
        throwsArgumentError,
      );

      expect(
        () => BorradorFacturaPedido(descuentoPorcentaje: 120.0),
        throwsArgumentError,
      );
    });
  });

  group('Fecha prevista de entrega y alertas', () {
    // 2026-11-13 12:00 Honduras = 2026-11-13 18:00 UTC
    final referenciaMediodiaHn = DateTime.utc(2026, 11, 13, 18, 0);

    test('1. Pedido sin fecha devuelve AlertaEntregaPedido.sinFecha', () {
      final pedido = Pedido(
        id: 'ped-f1',
        clienteId: 'cli-1',
        clienteNombre: 'Ana López',
      );

      expect(pedido.fechaPrevistaEntrega, isNull);
      expect(
        pedido.calcularAlertaEntrega(referencia: referenciaMediodiaHn),
        AlertaEntregaPedido.sinFecha,
      );
    });

    test('2. Entrega atrasada devuelve AlertaEntregaPedido.atrasado', () {
      final pedido = Pedido(
        id: 'ped-f2',
        clienteId: 'cli-1',
        clienteNombre: 'Ana López',
        fechaPrevistaEntrega: DateTime(2026, 11, 12),
      );

      expect(
        pedido.calcularAlertaEntrega(referencia: referenciaMediodiaHn),
        AlertaEntregaPedido.atrasado,
      );
    });

    test('3. Entrega hoy devuelve AlertaEntregaPedido.hoy', () {
      final pedido = Pedido(
        id: 'ped-f3',
        clienteId: 'cli-1',
        clienteNombre: 'Ana López',
        fechaPrevistaEntrega: DateTime(2026, 11, 13),
      );

      expect(
        pedido.calcularAlertaEntrega(referencia: referenciaMediodiaHn),
        AlertaEntregaPedido.hoy,
      );
    });

    test('4. Entrega mañana devuelve AlertaEntregaPedido.manana', () {
      final pedido = Pedido(
        id: 'ped-f4',
        clienteId: 'cli-1',
        clienteNombre: 'Ana López',
        fechaPrevistaEntrega: DateTime(2026, 11, 14),
      );

      expect(
        pedido.calcularAlertaEntrega(referencia: referenciaMediodiaHn),
        AlertaEntregaPedido.manana,
      );
    });

    test('5. Entrega futura devuelve AlertaEntregaPedido.futura', () {
      final pedido = Pedido(
        id: 'ped-f5',
        clienteId: 'cli-1',
        clienteNombre: 'Ana López',
        fechaPrevistaEntrega: DateTime(2026, 11, 15),
      );

      expect(
        pedido.calcularAlertaEntrega(referencia: referenciaMediodiaHn),
        AlertaEntregaPedido.futura,
      );
    });

    test(
      '6. Pedido entregado con fecha vencida devuelve entregado y no atrasado',
      () {
        final pedido = Pedido(
          id: 'ped-f6',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          estadoEnvio: EstadoEnvioPedido.entregado,
          fechaPrevistaEntrega: DateTime(2026, 11, 10),
        );

        expect(
          pedido.calcularAlertaEntrega(referencia: referenciaMediodiaHn),
          AlertaEntregaPedido.entregado,
        );
      },
    );

    test('7. Actualiza y limpia fechaPrevistaEntrega mediante copyWith', () {
      final pedido = Pedido(
        id: 'ped-f7',
        clienteId: 'cli-1',
        clienteNombre: 'Ana López',
      );

      final conFecha = pedido.copyWith(
        fechaPrevistaEntrega: DateTime(2026, 11, 20),
      );
      expect(conFecha.fechaPrevistaEntrega, DateTime.utc(2026, 11, 20, 18));

      final actualizada = conFecha.copyWith(
        fechaPrevistaEntrega: DateTime(2026, 11, 22),
      );
      expect(actualizada.fechaPrevistaEntrega, DateTime.utc(2026, 11, 22, 18));

      final limpiada = actualizada.copyWith(limpiarFechaPrevistaEntrega: true);
      expect(limpiada.fechaPrevistaEntrega, isNull);
    });

    test(
      '8. Serializa y deserializa fechaPrevistaEntrega con Timestamp a las 18:00 UTC',
      () {
        final pedido = Pedido(
          id: 'ped-f8',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          fechaPrevistaEntrega: DateTime(2026, 11, 18),
        );

        final mapa = pedido.toMap();
        final ts = mapa['fechaPrevistaEntrega'];
        expect(ts, isA<Timestamp>());
        expect(
          (ts as Timestamp).toDate().toUtc(),
          DateTime.utc(2026, 11, 18, 18),
        );

        final reconstruido = Pedido.fromMap(mapa, id: 'ped-f8');
        expect(
          reconstruido.fechaPrevistaEntrega,
          DateTime.utc(2026, 11, 18, 18),
        );
        expect(reconstruido.fechaPrevistaEntrega?.year, 2026);
        expect(reconstruido.fechaPrevistaEntrega?.month, 11);
        expect(reconstruido.fechaPrevistaEntrega?.day, 18);
      },
    );

    test(
      '9. Compatibilidad con documentos antiguos sin campo fechaPrevistaEntrega',
      () {
        final mapaAntiguo = {
          'id': 'ped-antiguo',
          'clienteId': 'cli-1',
          'clienteNombre': 'Ana López',
          'items': <Map<String, dynamic>>[],
          'estadoEnvio': 'pendiente',
          'costoEnvio': 0.0,
          'facturado': false,
        };

        final pedido = Pedido.fromMap(mapaAntiguo);
        expect(pedido.fechaPrevistaEntrega, isNull);
        expect(
          pedido.calcularAlertaEntrega(referencia: referenciaMediodiaHn),
          AlertaEntregaPedido.sinFecha,
        );
      },
    );

    test(
      '10. Respeta bordes horarios cercanos a medianoche en Honduras (UTC-6)',
      () {
        final pedido = Pedido(
          id: 'ped-f10',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          fechaPrevistaEntrega: DateTime(2026, 11, 13),
        );

        // 2026-11-13 23:59 Honduras = 2026-11-14 05:59 UTC (aún es hoy en HN)
        final antesMedianocheHn = DateTime.utc(2026, 11, 14, 5, 59);
        expect(
          pedido.calcularAlertaEntrega(referencia: antesMedianocheHn),
          AlertaEntregaPedido.hoy,
        );

        // 2026-11-14 00:00 Honduras = 2026-11-14 06:00 UTC (ya es atrasado en HN)
        final medianocheHn = DateTime.utc(2026, 11, 14, 6, 0);
        expect(
          pedido.calcularAlertaEntrega(referencia: medianocheHn),
          AlertaEntregaPedido.atrasado,
        );
      },
    );

    test(
      '11. Conserva exactamente el día calendario al guardar y recuperar',
      () {
        // Simula selección desde calendario local y UTC
        final fechaDesdePicker = DateTime(2026, 12, 31);
        final pedido = Pedido(
          id: 'ped-f11',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          fechaPrevistaEntrega: fechaDesdePicker,
        );

        final mapa = pedido.toMap();
        final recuperado = Pedido.fromMap(mapa, id: 'ped-f11');

        expect(recuperado.fechaPrevistaEntrega?.year, 2026);
        expect(recuperado.fechaPrevistaEntrega?.month, 12);
        expect(recuperado.fechaPrevistaEntrega?.day, 31);
        expect(
          recuperado.calcularAlertaEntrega(
            referencia: DateTime.utc(2026, 12, 31, 6, 0),
          ),
          AlertaEntregaPedido.hoy,
        );
      },
    );
  });
}
