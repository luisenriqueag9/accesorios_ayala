import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/models/cliente.dart';
import 'package:accesorios_ayala/models/producto.dart';
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

  final productosPrueba = <Producto>[
    Producto(
      id: 'prod-1',
      nombre: 'Pulsera Ónix Dorado',
      descripcion: 'Piedra natural con dije',
      precio: 350.0,
    ),
    Producto(
      id: 'prod-2',
      nombre: 'Collar Perla Clásica',
      descripcion: 'Acero inoxidable 45cm',
      precio: 520.5,
    ),
    Producto(
      id: 'prod-3',
      nombre: 'Aretes Ámbar Sutil',
      descripcion: 'Baño de oro 18k',
      precio: 240.0,
    ),
  ];

  Widget construirVistaPrueba({List<Producto> productos = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: NuevoPedidoView(
            clientes: clientesPrueba,
            productos: productos,
          ),
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

  group('NuevoPedidoView - Buscador y selección de productos', () {
    testWidgets(
      'muestra el buscador de productos sin desplegar resultados inicialmente',
      (tester) async {
        await tester.pumpWidget(
          construirVistaPrueba(productos: productosPrueba),
        );

        expect(find.text('Productos'), findsOneWidget);
        expect(find.text('Buscar producto por nombre'), findsOneWidget);
        expect(find.text('Pulsera Ónix Dorado'), findsNothing);
        expect(find.text('Collar Perla Clásica'), findsNothing);
      },
    );

    testWidgets(
      'filtra productos por nombre ignorando mayúsculas y tildes',
      (tester) async {
        await tester.pumpWidget(
          construirVistaPrueba(productos: productosPrueba),
        );

        final buscadorProductos = find.widgetWithText(
          TextField,
          'Buscar producto por nombre',
        );
        await tester.tap(buscadorProductos);
        await tester.pump();

        await tester.enterText(buscadorProductos, 'onix');
        await tester.pump();
        expect(find.text('Pulsera Ónix Dorado'), findsOneWidget);
        expect(find.text('L. 350.00'), findsOneWidget);
        expect(find.text('Collar Perla Clásica'), findsNothing);

        await tester.enterText(buscadorProductos, 'CLASICA');
        await tester.pump();
        expect(find.text('Collar Perla Clásica'), findsOneWidget);
        expect(find.text('L. 520.50'), findsOneWidget);
        expect(find.text('Pulsera Ónix Dorado'), findsNothing);
      },
    );

    testWidgets(
      'muestra "No se encontraron productos" cuando no hay coincidencias',
      (tester) async {
        await tester.pumpWidget(
          construirVistaPrueba(productos: productosPrueba),
        );

        final buscadorProductos = find.widgetWithText(
          TextField,
          'Buscar producto por nombre',
        );
        await tester.tap(buscadorProductos);
        await tester.pump();
        await tester.enterText(buscadorProductos, 'Producto Inexistente');
        await tester.pump();

        expect(find.text('No se encontraron productos'), findsOneWidget);
      },
    );

    testWidgets(
      'permite agregar varios productos distintos a la lista de seleccionados',
      (tester) async {
        await tester.pumpWidget(
          construirVistaPrueba(productos: productosPrueba),
        );

        final buscadorProductos = find.widgetWithText(
          TextField,
          'Buscar producto por nombre',
        );

        await tester.tap(buscadorProductos);
        await tester.pump();
        await tester.tap(find.text('Pulsera Ónix Dorado'));
        await tester.pump();

        await tester.tap(find.byTooltip('Mostrar lista de productos'));
        await tester.pumpAndSettle();

        expect(find.text('Collar Perla Clásica'), findsOneWidget);
        await tester.tap(find.text('Collar Perla Clásica'));
        await tester.pump();

        expect(find.text('Pulsera Ónix Dorado'), findsOneWidget);
        expect(find.text('Precio unitario: L. 350.00'), findsOneWidget);
        expect(find.text('Subtotal: L. 350.00'), findsOneWidget);
        expect(find.text('Collar Perla Clásica'), findsOneWidget);
        expect(find.text('Precio unitario: L. 520.50'), findsOneWidget);
        expect(find.text('Subtotal: L. 520.50'), findsOneWidget);
        expect(find.text('Subtotal general'), findsOneWidget);
        expect(find.text('L. 870.50'), findsOneWidget);
      },
    );

    testWidgets(
      'seleccionar dos veces el mismo producto incrementa su cantidad sin duplicar fila',
      (tester) async {
        await tester.pumpWidget(
          construirVistaPrueba(productos: productosPrueba),
        );

        final buscadorProductos = find.widgetWithText(
          TextField,
          'Buscar producto por nombre',
        );

        await tester.tap(buscadorProductos);
        await tester.pump();
        await tester.tap(find.text('Aretes Ámbar Sutil'));
        await tester.pump();

        expect(find.text('1'), findsOneWidget);
        expect(find.text('Subtotal: L. 240.00'), findsOneWidget);

        await tester.tap(find.byTooltip('Mostrar lista de productos'));
        await tester.pumpAndSettle();

        final resultadoAretes = find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Aretes Ámbar Sutil'),
        );
        expect(resultadoAretes, findsOneWidget);
        await tester.tap(resultadoAretes);
        await tester.pump();

        expect(find.text('Aretes Ámbar Sutil'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Precio unitario: L. 240.00'), findsOneWidget);
        expect(find.text('Subtotal: L. 480.00'), findsOneWidget);
        expect(find.text('L. 480.00'), findsOneWidget);
      },
    );

    testWidgets(
      'los botones + y - ajustan cantidades sin bajar de 1 y actualizan subtotales',
      (tester) async {
        await tester.pumpWidget(
          construirVistaPrueba(productos: productosPrueba),
        );

        final buscadorProductos = find.widgetWithText(
          TextField,
          'Buscar producto por nombre',
        );

        await tester.tap(buscadorProductos);
        await tester.pump();
        await tester.tap(find.text('Pulsera Ónix Dorado'));
        await tester.pump();

        // Cantidad inicial = 1; intentar disminuir no baja de 1
        await tester.tap(find.byTooltip('Disminuir cantidad'));
        await tester.pump();
        expect(find.text('1'), findsOneWidget);
        expect(find.text('Subtotal: L. 350.00'), findsOneWidget);
        expect(find.text('L. 350.00'), findsOneWidget);

        // Aumentar cantidad a 3
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Subtotal: L. 1050.00'), findsOneWidget);
        expect(find.text('L. 1050.00'), findsOneWidget);

        // Disminuir cantidad a 2
        await tester.tap(find.byTooltip('Disminuir cantidad'));
        await tester.pump();
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Subtotal: L. 700.00'), findsOneWidget);
        expect(find.text('L. 700.00'), findsOneWidget);
      },
    );

    testWidgets(
      'permite eliminar un producto seleccionado y actualiza el subtotal general',
      (tester) async {
        await tester.pumpWidget(
          construirVistaPrueba(productos: productosPrueba),
        );

        final buscadorProductos = find.widgetWithText(
          TextField,
          'Buscar producto por nombre',
        );

        await tester.tap(buscadorProductos);
        await tester.pump();
        await tester.tap(find.text('Pulsera Ónix Dorado'));
        await tester.pump();

        await tester.tap(find.byTooltip('Mostrar lista de productos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aretes Ámbar Sutil'));
        await tester.pump();

        expect(find.text('L. 590.00'), findsOneWidget);

        await tester.tap(find.byTooltip('Eliminar producto').first);
        await tester.pump();

        expect(find.text('Pulsera Ónix Dorado'), findsNothing);
        expect(find.text('Aretes Ámbar Sutil'), findsOneWidget);
        expect(find.text('L. 240.00'), findsOneWidget);

        await tester.tap(find.byTooltip('Eliminar producto'));
        await tester.pump();

        expect(find.text('Aretes Ámbar Sutil'), findsNothing);
        expect(find.text('Subtotal general'), findsNothing);
      },
    );

    testWidgets(
      'acepta productos: const [] sin requerir Firebase',
      (tester) async {
        await tester.pumpWidget(construirVistaPrueba(productos: const []));

        expect(find.text('No hay productos registrados'), findsOneWidget);
      },
    );
  });
}
