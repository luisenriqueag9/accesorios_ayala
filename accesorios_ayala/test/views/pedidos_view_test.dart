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
}
