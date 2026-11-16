import 'package:accesorios_ayala/models/producto.dart';
import 'package:accesorios_ayala/views/catalogo_publico_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Producto _p(
  String id,
  String nombre, {
  String descripcion = 'Detalle artesanal',
  bool visible = true,
  List<String> categoriaIds = const [],
}) => Producto(
  id: id,
  nombre: nombre,
  descripcion: descripcion,
  precio: 100,
  visibleCatalogo: visible,
  categoriaIds: categoriaIds,
);

final _productos = <Producto>[
  _p(
    'p1',
    'Pulsera Dorada',
    descripcion: 'Acero inoxidable',
    categoriaIds: ['idPulseras'],
  ),
  _p('p2', 'Collar Perla', descripcion: 'Diseño clásico con PERLAS'),
  _p('p3', 'Llavero Secreto', visible: false),
  _p('p4', 'Taza Grabada', descripcion: 'Grabado láser personalizado'),
];

Future<void> _montar(
  WidgetTester tester,
  Future<List<Producto>> Function() cargar,
) async {
  tester.view.physicalSize = const Size(1400, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(home: CatalogoPublicoView(cargarProductos: cargar)),
  );
  // Evita pumpAndSettle por posibles animaciones continuas del diseño.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _buscar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
}

void main() {
  group('filtrarProductosCatalogo', () {
    test('excluye ocultos, conserva orden y no modifica la lista original', () {
      final original = List<Producto>.of(_productos);
      final r = filtrarProductosCatalogo(_productos, '');
      expect(r.map((p) => p.id), ['p1', 'p2', 'p4']);
      expect(_productos.map((p) => p.id), original.map((p) => p.id));
    });

    test('busca por nombre o descripción sin distinguir mayúsculas', () {
      expect(
        filtrarProductosCatalogo(_productos, '  pULSERA ').map((p) => p.id),
        ['p1'],
      );
      expect(
        filtrarProductosCatalogo(_productos, 'perlas').map((p) => p.id),
        ['p2'],
      );
      expect(filtrarProductosCatalogo(_productos, 'secreto'), isEmpty);
    });
  });

  group('CatalogoPublicoView - visibilidad y búsqueda', () {
    testWidgets('muestra productos visibles y excluye ocultos', (tester) async {
      await _montar(tester, () async => _productos);

      expect(find.text('Pulsera Dorada'), findsOneWidget);
      expect(find.text('Collar Perla'), findsOneWidget);
      expect(find.text('Taza Grabada'), findsOneWidget);
      expect(find.text('Llavero Secreto'), findsNothing);
      expect(find.text('3 creaciones'), findsOneWidget);
    });

    testWidgets('los productos antiguos sin categorías siguen apareciendo', (
      tester,
    ) async {
      final antiguo = Producto.fromMap({
        'id': 'antiguo',
        'nombre': 'Aretes Antiguos',
        'descripcion': 'Sin categorías',
        'precio': 90,
      });
      await _montar(tester, () async => [antiguo]);

      expect(antiguo.categoriaIds, isEmpty);
      expect(find.text('Aretes Antiguos'), findsOneWidget);
    });

    testWidgets('busca por nombre', (tester) async {
      await _montar(tester, () async => _productos);
      await _buscar(tester, 'Collar');

      expect(find.text('Collar Perla'), findsOneWidget);
      expect(find.text('Pulsera Dorada'), findsNothing);
      expect(find.text('Taza Grabada'), findsNothing);
    });

    testWidgets('busca por descripción', (tester) async {
      await _montar(tester, () async => _productos);
      await _buscar(tester, 'láser');

      expect(find.text('Taza Grabada'), findsOneWidget);
      expect(find.text('Pulsera Dorada'), findsNothing);
    });

    testWidgets('la búsqueda no distingue mayúsculas', (tester) async {
      await _montar(tester, () async => _productos);
      await _buscar(tester, 'ACERO');

      expect(find.text('Pulsera Dorada'), findsOneWidget);
      expect(find.text('Collar Perla'), findsNothing);
    });

    testWidgets('la búsqueda no revela productos ocultos', (tester) async {
      await _montar(tester, () async => _productos);
      await _buscar(tester, 'Llavero');

      expect(find.text('Llavero Secreto'), findsNothing);
      expect(
        find.text('No encontramos productos que coincidan'),
        findsOneWidget,
      );
    });

    testWidgets('si todos están ocultos muestra el estado de catálogo vacío', (
      tester,
    ) async {
      await _montar(
        tester,
        () async => [
          _p('o1', 'Oculto Uno', visible: false),
          _p('o2', 'Oculto Dos', visible: false),
        ],
      );

      expect(find.text('Aún no hay productos disponibles'), findsOneWidget);
      expect(find.text('No encontramos productos que coincidan'), findsNothing);
      expect(find.text('Oculto Uno'), findsNothing);
    });

    testWidgets('sin coincidencias muestra el mensaje de búsqueda', (
      tester,
    ) async {
      await _montar(tester, () async => _productos);
      await _buscar(tester, 'zzz-inexistente');

      expect(
        find.text('No encontramos productos que coincidan'),
        findsOneWidget,
      );
      expect(find.text('Aún no hay productos disponibles'), findsNothing);
    });

    testWidgets('una carga fallida muestra el estado de error', (
      tester,
    ) async {
      await _montar(tester, () => Future.error(Exception('sin conexión')));

      expect(
        find.text('No se pudieron cargar los productos en este momento.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets(
      'cambiar y limpiar la búsqueda no altera los productos originales',
      (tester) async {
        final fuente = List<Producto>.of(_productos);
        await _montar(tester, () async => fuente);

        await _buscar(tester, 'Collar');
        expect(find.text('1 creación'), findsOneWidget);

        await _buscar(tester, '');
        expect(find.text('3 creaciones'), findsOneWidget);
        expect(find.text('Pulsera Dorada'), findsOneWidget);
        expect(find.text('Taza Grabada'), findsOneWidget);
        expect(find.text('Llavero Secreto'), findsNothing);
        expect(fuente.map((p) => p.id), ['p1', 'p2', 'p3', 'p4']);
      },
    );
  });
}
