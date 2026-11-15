import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/models/pedido.dart';
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
}
