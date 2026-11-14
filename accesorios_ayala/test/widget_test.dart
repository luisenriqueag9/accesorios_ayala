import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/views/pedidos_view.dart';

void main() {
  testWidgets('PedidosView muestra su submenú y cambia entre secciones sin Firebase',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PedidosView(),
          ),
        ),
      ),
    );

    expect(find.text('Resumen de pedidos'), findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Pedidos'), findsNWidgets(2));
    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(find.text('Reportes'), findsOneWidget);
    expect(find.text('Alertas'), findsOneWidget);

    await tester.tap(find.text('Pedidos').last);
    await tester.pump();

    expect(find.text('No hay pedidos registrados'), findsOneWidget);
  });
}
