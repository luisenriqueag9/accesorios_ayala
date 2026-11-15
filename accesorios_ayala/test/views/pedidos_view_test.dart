import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/models/pedido.dart';
import 'package:accesorios_ayala/models/venta.dart';
import 'package:accesorios_ayala/views/pedidos_view.dart';

void main() {
  Pedido crearPedido({
    EstadoElaboracionPedido estadoItem1 = EstadoElaboracionPedido.terminado,
    EstadoElaboracionPedido estadoItem2 = EstadoElaboracionPedido.terminado,
    bool facturado = false,
    String? ventaId,
    String? facturaNumero,
  }) {
    return Pedido(
      id: 'ped-ui-1',
      numeroPedido: 'PED-0021',
      clienteId: 'cli-1',
      clienteNombre: 'Ana López',
      items: [
        PedidoItem(
          itemId: 'item-1',
          productoId: 'prod-1',
          nombre: 'Pulsera Dorada',
          cantidad: 1,
          precioUnitario: 200.0,
          estadoElaboracion: estadoItem1,
        ),
        PedidoItem(
          itemId: 'item-2',
          productoId: 'prod-2',
          nombre: 'Collar Perla',
          cantidad: 1,
          precioUnitario: 350.0,
          estadoElaboracion: estadoItem2,
        ),
      ],
      facturado: facturado,
      ventaId: ventaId,
      facturaNumero: facturaNumero,
    );
  }

  Future<void> abrirDetallePedido(WidgetTester tester, Pedido pedido) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PedidosView(pedidos: [pedido]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedidos').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(pedido.numeroPedido).first);
    await tester.pumpAndSettle();
  }

  ButtonStyleButton obtenerBotonFacturar(WidgetTester tester) {
    return tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Facturar pedido'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
  }

  group('PedidosView - Opción Facturar pedido en detalle', () {
    testWidgets(
      'habilita Facturar pedido cuando todos los accesorios están terminados y no está facturado',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());

        expect(find.text('Facturar pedido'), findsOneWidget);
        expect(obtenerBotonFacturar(tester).enabled, isTrue);
        expect(
          find.textContaining('Pedido listo para facturar'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'mantiene Facturar pedido deshabilitado cuando hay accesorios en proceso o recibidos',
      (tester) async {
        await abrirDetallePedido(
          tester,
          crearPedido(estadoItem2: EstadoElaboracionPedido.enProceso),
        );

        expect(find.text('Facturar pedido'), findsOneWidget);
        expect(obtenerBotonFacturar(tester).enabled, isFalse);
      },
    );

    testWidgets(
      'deshabilita Facturar pedido cuando existen cambios provisionales sin guardar',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());
        expect(obtenerBotonFacturar(tester).enabled, isTrue);

        await tester.tap(find.text('En proceso').first);
        await tester.pumpAndSettle();

        expect(obtenerBotonFacturar(tester).enabled, isFalse);
      },
    );

    testWidgets(
      'muestra condición de facturado y deshabilita Facturar pedido si ya fue facturado o tiene ventaId',
      (tester) async {
        await abrirDetallePedido(
          tester,
          crearPedido(
            facturado: true,
            ventaId: 'venta-99',
            facturaNumero: 'FAC-0099',
          ),
        );

        expect(find.textContaining('Pedido facturado'), findsWidgets);
        expect(obtenerBotonFacturar(tester).enabled, isFalse);
      },
    );
  });

  group('PedidosView - Edición de fecha prevista de entrega', () {
    IconButton obtenerBotonEditarFecha(WidgetTester tester) {
      return tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Editar fecha de entrega'),
          matching: find.byType(IconButton),
        ),
      );
    }

    testWidgets(
      'habilita edición de fecha en pedido no facturado y la deshabilita con cambios provisionales',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());

        expect(obtenerBotonEditarFecha(tester).onPressed, isNotNull);

        await tester.tap(find.text('En proceso').first);
        await tester.pumpAndSettle();

        expect(obtenerBotonEditarFecha(tester).onPressed, isNull);
      },
    );

    testWidgets(
      'deshabilita edición de fecha cuando el pedido ya fue facturado',
      (tester) async {
        await abrirDetallePedido(
          tester,
          crearPedido(
            facturado: true,
            ventaId: 'venta-99',
            facturaNumero: 'FAC-0099',
          ),
        );

        expect(obtenerBotonEditarFecha(tester).onPressed, isNull);
      },
    );

    testWidgets(
      'muestra diálogo de confirmación con la nueva fecha antes de guardar',
      (tester) async {
        final pedidoConFecha = Pedido(
          id: 'ped-ui-fecha',
          numeroPedido: 'PED-0022',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          fechaPrevistaEntrega: DateTime.utc(2025, 5, 15, 18),
          items: [
            PedidoItem(
              itemId: 'item-1',
              productoId: 'prod-1',
              nombre: 'Pulsera Dorada',
              cantidad: 1,
              precioUnitario: 200.0,
              estadoElaboracion: EstadoElaboracionPedido.terminado,
            ),
          ],
        );

        await abrirDetallePedido(tester, pedidoConFecha);

        await tester.tap(find.byTooltip('Editar fecha de entrega'));
        await tester.pumpAndSettle();

        // Seleccionar el día 10 del mismo mes (fecha histórica permitida)
        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          find.text('Confirmar nueva fecha de entrega'),
          findsOneWidget,
        );
        expect(find.text('Fecha actual: 15/05/2025'), findsOneWidget);
        expect(find.text('Nueva fecha: 10/05/2025'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      },
    );
  });

  group('PedidosView - Quitar accesorio del pedido', () {
    List<IconButton> obtenerBotonesQuitar(WidgetTester tester) {
      return tester
          .widgetList<IconButton>(
            find.ancestor(
              of: find.byTooltip('Quitar accesorio'),
              matching: find.byType(IconButton),
            ),
          )
          .toList();
    }

    testWidgets(
      'habilita Quitar accesorio con múltiples ítems y lo bloquea con cambios provisionales',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());

        final botones = obtenerBotonesQuitar(tester);
        expect(botones, hasLength(2));
        expect(botones.every((b) => b.onPressed != null), isTrue);

        await tester.tap(find.text('En proceso').first);
        await tester.pumpAndSettle();

        final botonesBloqueados = obtenerBotonesQuitar(tester);
        expect(botonesBloqueados.every((b) => b.onPressed == null), isTrue);
      },
    );

    testWidgets(
      'deshabilita Quitar accesorio cuando solo queda un accesorio o el pedido está facturado',
      (tester) async {
        final pedidoUnItem = Pedido(
          id: 'ped-uno',
          numeroPedido: 'PED-0030',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          items: [
            PedidoItem(
              itemId: 'item-1',
              productoId: 'prod-1',
              nombre: 'Pulsera Única',
              cantidad: 1,
              precioUnitario: 200.0,
            ),
          ],
        );

        await abrirDetallePedido(tester, pedidoUnItem);
        final botonesUnItem = obtenerBotonesQuitar(tester);
        expect(botonesUnItem, hasLength(1));
        expect(botonesUnItem.single.onPressed, isNull);

        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        await abrirDetallePedido(
          tester,
          crearPedido(
            facturado: true,
            ventaId: 'venta-99',
            facturaNumero: 'FAC-0099',
          ),
        );
        final botonesFacturado = obtenerBotonesQuitar(tester);
        expect(botonesFacturado.every((b) => b.onPressed == null), isTrue);
      },
    );

    testWidgets(
      'muestra confirmación con nombre, personalización y aviso de recálculo antes de eliminar',
      (tester) async {
        final pedidoPersonalizado = Pedido(
          id: 'ped-pers',
          numeroPedido: 'PED-0031',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          items: [
            PedidoItem(
              itemId: 'item-1',
              productoId: 'prod-1',
              nombre: 'Pulsera Dorada',
              cantidad: 1,
              precioUnitario: 200.0,
              notaPersonalizacion: 'Iniciales A.L.',
            ),
            PedidoItem(
              itemId: 'item-2',
              productoId: 'prod-1',
              nombre: 'Pulsera Dorada',
              cantidad: 2,
              precioUnitario: 200.0,
              notaPersonalizacion: 'Iniciales M.P.',
            ),
          ],
        );

        await abrirDetallePedido(tester, pedidoPersonalizado);

        await tester.tap(find.byTooltip('Quitar accesorio').last);
        await tester.pumpAndSettle();

        final dialogoConfirmacion = find.byType(AlertDialog);
        expect(dialogoConfirmacion, findsOneWidget);
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Pulsera Dorada'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Personalización: Iniciales M.P.'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Cantidad: 2'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.textContaining(
              'se actualizarán los importes del pedido',
            ),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Cancelar'),
          ),
        );
        await tester.pumpAndSettle();
      },
    );
  });

  group('PedidosView - Pestaña Facturas (historial de solo lectura)', () {
    Venta crearFactura({
      required String id,
      required String clienteNombre,
      required DateTime fecha,
      required double total,
    }) {
      return Venta(
        id: id,
        clienteId: 'cli-1',
        clienteNombre: clienteNombre,
        fecha: fecha,
        subtotal: total,
        impuesto: 0.0,
        total: total,
      );
    }

    Future<void> montarVistaFacturas(
      WidgetTester tester, {
      required Size tamano,
      List<Pedido>? pedidos,
      List<Venta>? facturas,
      Future<List<Venta>> Function()? onCargarFacturas,
    }) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PedidosView(
                pedidos: pedidos ?? const [],
                facturas: facturas,
                onCargarFacturas: onCargarFacturas,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'realiza carga diferida únicamente al abrir la pestaña Facturas y muestra estado de carga',
      (tester) async {
        var llamadas = 0;
        final completer = Completer<List<Venta>>();

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          onCargarFacturas: () {
            llamadas++;
            return completer.future;
          },
        );

        expect(llamadas, 0);

        await tester.tap(find.text('Facturas'));
        await tester.pump();

        expect(llamadas, 1);
        expect(find.text('Cargando facturas...'), findsOneWidget);

        completer.complete([
          crearFactura(
            id: 'FAC-0001',
            clienteNombre: 'Ana López',
            fecha: DateTime(2026, 11, 15, 10, 0),
            total: 620.0,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('Ana López'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra tabla en escritorio con pedido relacionado y guión cuando no está en memoria',
      (tester) async {
        final pedidosEnMemoria = [
          crearPedido(
            facturado: true,
            ventaId: 'FAC-0002',
            facturaNumero: 'FAC-0002',
          ),
        ];
        final listaFacturas = [
          crearFactura(
            id: 'FAC-0002',
            clienteNombre: 'Ana López',
            fecha: DateTime(2026, 11, 15, 14, 0),
            total: 920.50,
          ),
          crearFactura(
            id: 'FAC-0001',
            clienteNombre: 'Carlos Pérez',
            fecha: DateTime(2026, 11, 14, 9, 0),
            total: 450.0,
          ),
        ];

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          pedidos: pedidosEnMemoria,
          facturas: listaFacturas,
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        expect(find.text('N.º Factura'), findsOneWidget);
        expect(find.text('Cliente'), findsOneWidget);
        expect(find.text('Pedido'), findsOneWidget);
        expect(find.text('Fecha'), findsOneWidget);
        expect(find.text('Total'), findsOneWidget);

        expect(find.text('FAC-0002'), findsOneWidget);
        expect(find.text('Ana López'), findsOneWidget);
        expect(find.text('PED-0021'), findsOneWidget);
        expect(find.text('L. 920.50'), findsOneWidget);

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('Carlos Pérez'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
        expect(find.text('L. 450.00'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra tarjetas en móvil sin desbordamiento horizontal',
      (tester) async {
        final pedidosEnMemoria = [
          crearPedido(
            facturado: true,
            ventaId: 'FAC-0010',
            facturaNumero: 'FAC-0010',
          ),
        ];

        await montarVistaFacturas(
          tester,
          tamano: const Size(390, 844),
          pedidos: pedidosEnMemoria,
          facturas: [
            crearFactura(
              id: 'FAC-0010',
              clienteNombre: 'María Fernanda Rodríguez de la Cruz',
              fecha: DateTime(2026, 11, 15, 11, 0),
              total: 1250.0,
            ),
          ],
        );

        final pestanaFacturas = find.text('Facturas');
        await tester.ensureVisible(pestanaFacturas);
        await tester.pumpAndSettle();

        await tester.tap(pestanaFacturas);
        await tester.pumpAndSettle();

        expect(find.text('N.º Factura'), findsNothing);
        expect(find.text('FAC-0010'), findsOneWidget);
        expect(find.text('L. 1250.00'), findsOneWidget);
        expect(
          find.text('María Fernanda Rodríguez de la Cruz'),
          findsOneWidget,
        );
        expect(find.text('Pedido: PED-0021'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('muestra estado vacío cuando no hay facturas emitidas', (
      tester,
    ) async {
      await montarVistaFacturas(
        tester,
        tamano: const Size(1400, 900),
        onCargarFacturas: () async => [],
      );

      await tester.tap(find.text('Facturas'));
      await tester.pumpAndSettle();

      expect(find.text('No hay facturas emitidas'), findsOneWidget);
    });

    testWidgets(
      'muestra error distinguido, permite reintentar y no bloquea otras pestañas',
      (tester) async {
        var intento = 0;

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          onCargarFacturas: () async {
            intento++;
            if (intento == 1) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              );
            }
            return [
              crearFactura(
                id: 'FAC-0005',
                clienteNombre: 'Elena Ruiz',
                fecha: DateTime(2026, 11, 15, 12, 0),
                total: 700.0,
              ),
            ];
          },
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        expect(find.text('No se pudieron cargar las facturas'), findsOneWidget);
        expect(find.textContaining('permisos suficientes'), findsOneWidget);

        // Las demás pestañas siguen operativas pese al error en Facturas.
        await tester.tap(find.text('Resumen'));
        await tester.pumpAndSettle();
        expect(find.text('Resumen de pedidos'), findsOneWidget);

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.text('FAC-0005'), findsOneWidget);
        expect(find.text('Elena Ruiz'), findsOneWidget);
      },
    );

    testWidgets(
      'actualiza sin duplicados y conserva facturas previas si falla una actualización',
      (tester) async {
        var intento = 0;
        final completerActualizacion = Completer<List<Venta>>();

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          onCargarFacturas: () {
            intento++;
            if (intento == 1) {
              return Future.value([
                crearFactura(
                  id: 'FAC-0001',
                  clienteNombre: 'Ana López',
                  fecha: DateTime(2026, 11, 14, 10, 0),
                  total: 500.0,
                ),
              ]);
            }
            if (intento == 2) {
              return completerActualizacion.future;
            }
            return Future.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              ),
            );
          },
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();
        expect(find.text('FAC-0001'), findsOneWidget);

        // Primera actualización: muestra indicador discreto y reemplaza sin duplicar.
        await tester.tap(find.text('Actualizar'));
        await tester.pump();
        expect(find.text('Actualizando facturas...'), findsOneWidget);
        expect(find.text('FAC-0001'), findsOneWidget);

        completerActualizacion.complete([
          crearFactura(
            id: 'FAC-0002',
            clienteNombre: 'Luis Gómez',
            fecha: DateTime(2026, 11, 15, 10, 0),
            total: 800.0,
          ),
          crearFactura(
            id: 'FAC-0001',
            clienteNombre: 'Ana López',
            fecha: DateTime(2026, 11, 14, 10, 0),
            total: 500.0,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('FAC-0002'), findsOneWidget);

        // Segunda actualización falla: conserva los datos y muestra aviso no bloqueante.
        await tester.tap(find.text('Actualizar'));
        await tester.pumpAndSettle();

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('FAC-0002'), findsOneWidget);
        expect(find.textContaining('Error de conexión'), findsOneWidget);
        expect(
          find.textContaining('Se muestran las facturas disponibles en memoria'),
          findsOneWidget,
        );
      },
    );
  });
}
