import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/models/cliente.dart';
import 'package:accesorios_ayala/views/nuevo_pedido_view.dart';

void main() {
  final clientesPrueba = <Cliente>[
    Cliente(
      id: 'cli-1',
      nombre: 'María José López',
      telefono: '9911-2233',
      direccion: 'Col. Palmira, Casa 14',
      departamento: 'Francisco Morazán',
    ),
    Cliente(
      id: 'cli-2',
      nombre: 'Andrés Álvarez',
      telefono: '8822-3344',
      direccion: 'Barrio Río de Piedras',
      departamento: 'Cortés',
    ),
    Cliente(
      id: 'cli-3',
      nombre: 'Sofía Núñez',
      telefono: '3344-5566',
      direccion: 'Residencial Las Colinas',
      departamento: 'Atlántida',
    ),
  ];

  Widget construirVistaPrueba() {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: NuevoPedidoView(clientes: clientesPrueba),
        ),
      ),
    );
  }

  group('NuevoPedidoView - Buscador de clientes', () {
    testWidgets(
      'muestra el campo "Buscar cliente por nombre" sin desplegar resultados inicialmente',
      (tester) async {
        await tester.pumpWidget(construirVistaPrueba());

        expect(find.text('Nuevo pedido'), findsOneWidget);
        expect(find.text('Cliente'), findsOneWidget);
        expect(find.text('Buscar cliente por nombre'), findsOneWidget);
        expect(find.text('María José López'), findsNothing);
        expect(find.text('Andrés Álvarez'), findsNothing);
      },
    );

    testWidgets(
      'filtra clientes por coincidencias parciales del nombre',
      (tester) async {
        await tester.pumpWidget(construirVistaPrueba());

        final buscador = find.byType(TextField);
        await tester.tap(buscador);
        await tester.pump();
        await tester.enterText(buscador, 'Álvar');
        await tester.pump();

        expect(find.text('Andrés Álvarez'), findsOneWidget);
        expect(find.text('María José López'), findsNothing);
        expect(find.text('Sofía Núñez'), findsNothing);
      },
    );

    testWidgets(
      'ignora mayúsculas, minúsculas y tildes al filtrar clientes',
      (tester) async {
        await tester.pumpWidget(construirVistaPrueba());

        final buscador = find.byType(TextField);
        await tester.tap(buscador);
        await tester.pump();

        await tester.enterText(buscador, 'maria jose');
        await tester.pump();
        expect(find.text('María José López'), findsOneWidget);
        expect(find.text('Andrés Álvarez'), findsNothing);

        await tester.enterText(buscador, 'NUNEZ');
        await tester.pump();
        expect(find.text('Sofía Núñez'), findsOneWidget);
        expect(find.text('María José López'), findsNothing);
      },
    );

    testWidgets(
      'permite seleccionar un cliente, oculta la lista y muestra sus datos',
      (tester) async {
        await tester.pumpWidget(construirVistaPrueba());

        await tester.tap(find.byType(TextField));
        await tester.pump();

        await tester.tap(find.text('María José López'));
        await tester.pump();

        // La lista de resultados se cierra y solo quedan visibles los datos seleccionados
        expect(find.byType(ListTile), findsNothing);
        expect(find.text('María José López'), findsOneWidget);
        expect(find.text('9911-2233'), findsOneWidget);
        expect(find.text('Col. Palmira, Casa 14'), findsOneWidget);
        expect(find.text('Francisco Morazán'), findsOneWidget);
      },
    );

    testWidgets(
      'permite cambiar de cliente mediante el botón "Cambiar"',
      (tester) async {
        await tester.pumpWidget(construirVistaPrueba());

        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.tap(find.text('María José López'));
        await tester.pump();

        expect(find.text('9911-2233'), findsOneWidget);

        await tester.tap(find.text('Cambiar'));
        await tester.pump();

        expect(find.byType(ListTile), findsNWidgets(3));

        await tester.tap(find.text('Andrés Álvarez'));
        await tester.pump();

        expect(find.byType(ListTile), findsNothing);
        expect(find.text('Andrés Álvarez'), findsOneWidget);
        expect(find.text('8822-3344'), findsOneWidget);
        expect(find.text('Barrio Río de Piedras'), findsOneWidget);
        expect(find.text('Cortés'), findsOneWidget);
        expect(find.text('9911-2233'), findsNothing);
      },
    );

    testWidgets(
      'muestra "No se encontraron clientes" cuando no hay coincidencias',
      (tester) async {
        await tester.pumpWidget(construirVistaPrueba());

        final buscador = find.byType(TextField);
        await tester.tap(buscador);
        await tester.pump();
        await tester.enterText(buscador, 'Cliente Inexistente');
        await tester.pump();

        expect(find.text('No se encontraron clientes'), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);
      },
    );

    testWidgets(
      'conserva la selección de cliente al reconstruirse por cambio de tamaño de pantalla',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(construirVistaPrueba());

        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.tap(find.text('Sofía Núñez'));
        await tester.pump();

        expect(find.text('Sofía Núñez'), findsOneWidget);
        expect(find.text('3344-5566'), findsOneWidget);

        // Cambiar a ancho móvil y reconstruir
        tester.view.physicalSize = const Size(420, 840);
        await tester.pump();

        expect(find.text('Sofía Núñez'), findsOneWidget);
        expect(find.text('3344-5566'), findsOneWidget);
        expect(find.text('Residencial Las Colinas'), findsOneWidget);
        expect(find.text('Atlántida'), findsOneWidget);

        // Volver a ancho escritorio y confirmar persistencia de selección
        tester.view.physicalSize = const Size(1200, 900);
        await tester.pump();

        expect(find.text('Sofía Núñez'), findsOneWidget);
        expect(find.text('3344-5566'), findsOneWidget);
      },
    );
  });
}
