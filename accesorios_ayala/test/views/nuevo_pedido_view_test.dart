import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/models/cliente.dart';
import 'package:accesorios_ayala/models/pedido.dart';
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

  Widget construirVistaPrueba({
    List<Producto> productos = const [],
    ValueChanged<List<PedidoItem>>? onItemsCambiados,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: NuevoPedidoView(
            clientes: clientesPrueba,
            productos: productos,
            onItemsCambiados: onItemsCambiados,
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

    testWidgets(
      'almacena cada unidad como PedidoItem independiente con cantidad 1 e itemId único manteniendo fila agrupada',
      (tester) async {
        List<PedidoItem> itemsActuales = const [];

        await tester.pumpWidget(
          construirVistaPrueba(
            productos: productosPrueba,
            onItemsCambiados: (items) => itemsActuales = items,
          ),
        );

        final buscadorProductos = find.widgetWithText(
          TextField,
          'Buscar producto por nombre',
        );

        await tester.tap(buscadorProductos);
        await tester.pump();
        await tester.tap(find.text('Pulsera Ónix Dorado'));
        await tester.pump();

        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();

        // UI permanece agrupada en una sola fila
        expect(find.text('Pulsera Ónix Dorado'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('Subtotal: L. 1050.00'), findsOneWidget);
        expect(find.text('L. 1050.00'), findsOneWidget);

        // Modelo interno: 3 unidades independientes con cantidad == 1 e itemId único
        expect(itemsActuales, hasLength(3));
        expect(itemsActuales.every((i) => i.cantidad == 1), isTrue);
        expect(itemsActuales.every((i) => i.productoId == 'prod-1'), isTrue);
        expect(
          itemsActuales.every(
            (i) => i.estadoElaboracion == EstadoElaboracionPedido.recibido,
          ),
          isTrue,
        );
        final idsTresUnidades = itemsActuales.map((i) => i.itemId).toList();
        expect(idsTresUnidades.toSet(), hasLength(3));

        // Al disminuir en 1, se conservan intactos los itemId de las unidades restantes
        await tester.tap(find.byTooltip('Disminuir cantidad'));
        await tester.pump();

        expect(find.text('2'), findsOneWidget);
        expect(itemsActuales, hasLength(2));
        final idsTrasDisminuir = itemsActuales.map((i) => i.itemId).toList();
        expect(idsTrasDisminuir, equals(idsTresUnidades.sublist(0, 2)));
        final idEliminado = idsTresUnidades.last;

        // Al volver a aumentar, se crea un nuevo itemId sin reutilizar el eliminado
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();

        expect(find.text('3'), findsOneWidget);
        expect(itemsActuales, hasLength(3));
        expect(
          itemsActuales.sublist(0, 2).map((i) => i.itemId).toList(),
          equals(idsTrasDisminuir),
        );
        expect(itemsActuales.last.itemId, isNot(equals(idEliminado)));
        expect(itemsActuales.map((i) => i.itemId).toSet(), hasLength(3));

        // Al eliminar el producto se remueven todas sus unidades
        await tester.tap(find.byTooltip('Eliminar producto'));
        await tester.pump();

        expect(itemsActuales, isEmpty);
        expect(find.text('Pulsera Ónix Dorado'), findsNothing);
        expect(find.text('Subtotal general'), findsNothing);
      },
    );
  });

  group('NuevoPedidoView - Personalización individual de unidades', () {
    Future<void> agregarPulseraConUnidades(
      WidgetTester tester, {
      required int unidades,
    }) async {
      final buscadorProductos = find.widgetWithText(
        TextField,
        'Buscar producto por nombre',
      );
      await tester.tap(buscadorProductos);
      await tester.pump();
      await tester.tap(find.text('Pulsera Ónix Dorado'));
      await tester.pump();

      for (var i = 1; i < unidades; i++) {
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();
      }
    }

    Finder campoUnidad(String itemId) {
      return find.descendant(
        of: find.byKey(ValueKey<String>('unidad-$itemId')),
        matching: find.byType(TextField),
      );
    }

    testWidgets(
      'muestra tres campos individuales, guarda instrucciones por itemId y conserva textos al contraer/expandir y aumentar',
      (tester) async {
        List<PedidoItem> itemsActuales = const [];

        await tester.pumpWidget(
          construirVistaPrueba(
            productos: productosPrueba,
            onItemsCambiados: (items) => itemsActuales = items,
          ),
        );

        await agregarPulseraConUnidades(tester, unidades: 3);
        expect(itemsActuales, hasLength(3));
        final ids = itemsActuales.map((i) => i.itemId).toList();

        // Expandir sección "Personalizar unidades"
        await tester.ensureVisible(find.text('Personalizar unidades'));
        await tester.tap(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();

        expect(find.text('Unidad 1'), findsOneWidget);
        expect(find.text('Unidad 2'), findsOneWidget);
        expect(find.text('Unidad 3'), findsOneWidget);
        expect(
          find.text('Personalización / instrucciones'),
          findsNWidgets(3),
        );

        // Escribir instrucciones distintas en cada unidad
        await tester.ensureVisible(campoUnidad(ids[0]));
        await tester.enterText(campoUnidad(ids[0]), 'Iniciales A.M.');
        await tester.ensureVisible(campoUnidad(ids[1]));
        await tester.enterText(campoUnidad(ids[1]), 'Medida 17 cm');
        await tester.ensureVisible(campoUnidad(ids[2]));
        await tester.enterText(campoUnidad(ids[2]), 'Broche dorado');
        await tester.pump();

        expect(itemsActuales[0].itemId, ids[0]);
        expect(itemsActuales[0].notaPersonalizacion, 'Iniciales A.M.');
        expect(itemsActuales[1].itemId, ids[1]);
        expect(itemsActuales[1].notaPersonalizacion, 'Medida 17 cm');
        expect(itemsActuales[2].itemId, ids[2]);
        expect(itemsActuales[2].notaPersonalizacion, 'Broche dorado');
        expect(find.text('Subtotal: L. 1050.00'), findsOneWidget);

        // Contraer y volver a expandir conserva los textos
        await tester.ensureVisible(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();

        expect(find.text('Iniciales A.M.'), findsOneWidget);
        expect(find.text('Medida 17 cm'), findsOneWidget);
        expect(find.text('Broche dorado'), findsOneWidget);

        // Aumentar cantidad a 4 conserva las 3 anteriores y agrega Unidad 4 vacía
        await tester.ensureVisible(find.byTooltip('Aumentar cantidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pumpAndSettle();

        expect(itemsActuales, hasLength(4));
        expect(find.text('Unidad 4'), findsOneWidget);
        expect(itemsActuales[0].notaPersonalizacion, 'Iniciales A.M.');
        expect(itemsActuales[1].notaPersonalizacion, 'Medida 17 cm');
        expect(itemsActuales[2].notaPersonalizacion, 'Broche dorado');
        expect(itemsActuales[3].notaPersonalizacion, isEmpty);
        expect(find.text('Subtotal: L. 1400.00'), findsOneWidget);
      },
    );

    testWidgets(
      'disminuir cantidad elimina primero una unidad sin instrucciones y pide confirmación cuando todas tienen instrucciones',
      (tester) async {
        List<PedidoItem> itemsActuales = const [];

        await tester.pumpWidget(
          construirVistaPrueba(
            productos: productosPrueba,
            onItemsCambiados: (items) => itemsActuales = items,
          ),
        );

        await agregarPulseraConUnidades(tester, unidades: 3);
        await tester.ensureVisible(find.text('Personalizar unidades'));
        await tester.tap(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();

        final ids = itemsActuales.map((i) => i.itemId).toList();

        // Personalizar solo Unidad 1 y Unidad 3 (Unidad 2 queda vacía)
        await tester.ensureVisible(campoUnidad(ids[0]));
        await tester.enterText(campoUnidad(ids[0]), 'Grabado 1');
        await tester.ensureVisible(campoUnidad(ids[2]));
        await tester.enterText(campoUnidad(ids[2]), 'Grabado 3');
        await tester.pump();

        // Disminuir: elimina Unidad 2 (vacía) sin mostrar diálogo
        await tester.ensureVisible(find.byTooltip('Disminuir cantidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Disminuir cantidad'));
        await tester.pumpAndSettle();

        expect(find.text('Disminuir cantidad'), findsNothing);
        expect(itemsActuales, hasLength(2));
        expect(itemsActuales[0].itemId, ids[0]);
        expect(itemsActuales[0].notaPersonalizacion, 'Grabado 1');
        expect(itemsActuales[1].itemId, ids[2]);
        expect(itemsActuales[1].notaPersonalizacion, 'Grabado 3');
        expect(find.text('Subtotal: L. 700.00'), findsOneWidget);

        // Ahora todas tienen instrucciones -> disminuir pide confirmación
        await tester.ensureVisible(find.byTooltip('Disminuir cantidad'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Disminuir cantidad'));
        await tester.pumpAndSettle();

        expect(find.text('Disminuir cantidad'), findsOneWidget);

        // Cancelar conserva todo
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(itemsActuales, hasLength(2));
        expect(itemsActuales[0].notaPersonalizacion, 'Grabado 1');
        expect(itemsActuales[1].notaPersonalizacion, 'Grabado 3');
      },
    );

    testWidgets(
      'eliminar producto con personalizaciones pide confirmación y volver a agregarlo no recupera instrucciones previas',
      (tester) async {
        List<PedidoItem> itemsActuales = const [];

        await tester.pumpWidget(
          construirVistaPrueba(
            productos: productosPrueba,
            onItemsCambiados: (items) => itemsActuales = items,
          ),
        );

        await agregarPulseraConUnidades(tester, unidades: 1);
        await tester.ensureVisible(find.text('Personalizar unidades'));
        await tester.tap(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();

        final primerId = itemsActuales.single.itemId;
        await tester.ensureVisible(campoUnidad(primerId));
        await tester.enterText(campoUnidad(primerId), 'Caja de regalo');
        await tester.pump();

        // Intentar eliminar -> pide confirmación
        await tester.ensureVisible(find.byTooltip('Eliminar producto'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Eliminar producto'));
        await tester.pumpAndSettle();
        expect(find.text('Eliminar producto'), findsOneWidget);

        // Cancelar conserva producto e instrucciones
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(itemsActuales, hasLength(1));
        expect(itemsActuales.single.notaPersonalizacion, 'Caja de regalo');

        // Confirmar eliminación
        await tester.ensureVisible(find.byTooltip('Eliminar producto'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Eliminar producto'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        expect(itemsActuales, isEmpty);
        expect(find.text('Pulsera Ónix Dorado'), findsNothing);

        // Volver a agregar el mismo producto -> no recupera la instrucción anterior
        await tester.ensureVisible(find.byTooltip('Mostrar lista de productos'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Mostrar lista de productos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pulsera Ónix Dorado'));
        await tester.pumpAndSettle();

        expect(itemsActuales, hasLength(1));
        expect(itemsActuales.single.itemId, isNot(equals(primerId)));
        expect(itemsActuales.single.notaPersonalizacion, isEmpty);

        await tester.ensureVisible(find.text('Personalizar unidades'));
        await tester.tap(find.text('Personalizar unidades'));
        await tester.pumpAndSettle();
        expect(find.text('Caja de regalo'), findsNothing);
      },
    );
  });
}
