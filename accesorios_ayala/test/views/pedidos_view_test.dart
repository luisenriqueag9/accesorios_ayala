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
          find.textContaining('disponible en la siguiente etapa'),
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
}
