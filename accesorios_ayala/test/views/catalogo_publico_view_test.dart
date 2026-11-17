import 'package:accesorios_ayala/models/banner_config.dart';
import 'package:accesorios_ayala/models/categoria.dart';
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

Categoria _c(
  String id,
  String nombre, {
  int orden = 0,
  bool visible = true,
}) => Categoria(id: id, nombre: nombre, orden: orden, visible: visible);

final _categorias = <Categoria>[
  _c('c3', 'Tazas', orden: 3),
  _c('c_oculta', 'Oculta', orden: 0, visible: false),
  _c('c1', 'Pulseras', orden: 1),
  _c('c2b', 'Collares', orden: 2),
  _c('c2a', 'Aretes', orden: 2),
];

Future<void> _montar(
  WidgetTester tester,
  Future<List<Producto>> Function() cargar, {
  Future<List<Categoria>> Function()? cargarCategorias,
  Future<BannerConfig> Function()? cargarBanner,
}) async {
  tester.view.physicalSize = const Size(1400, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: CatalogoPublicoView(
        cargarProductos: cargar,
        cargarCategorias: cargarCategorias ?? () async => const [],
        cargarBanner: cargarBanner ?? () async => BannerConfig.inicial(),
      ),
    ),
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

    test('filtra por categoriaId y combina con búsqueda sin duplicar', () {
      final lista = <Producto>[
        _p('a', 'Pulsera Mix', categoriaIds: ['c1', 'c2a']),
        _p(
          'b',
          'Collar Oro',
          descripcion: 'Con dije de corazón',
          categoriaIds: ['c2b'],
        ),
        _p('c', 'Sin Categoría'),
        _p('d', 'Oculto En Cat', visible: false, categoriaIds: ['c1']),
      ];

      expect(
        filtrarProductosCatalogo(lista, '', categoriaId: null).map((p) => p.id),
        ['a', 'b', 'c'],
      );
      expect(
        filtrarProductosCatalogo(lista, '', categoriaId: 'c1').map((p) => p.id),
        ['a'],
      );
      expect(
        filtrarProductosCatalogo(lista, '', categoriaId: 'c2a').map((p) => p.id),
        ['a'],
      );
      expect(
        filtrarProductosCatalogo(
          lista,
          'corazón',
          categoriaId: 'c2b',
        ).map((p) => p.id),
        ['b'],
      );
      expect(
        filtrarProductosCatalogo(lista, 'corazón', categoriaId: 'c1'),
        isEmpty,
      );
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

  group('prepararCategoriasCatalogo', () {
    test(
      'excluye ocultas, respeta orden administrativo y no modifica la lista original',
      () {
        final original = List<Categoria>.of(_categorias);
        final resultado = prepararCategoriasCatalogo(_categorias);

        expect(resultado.map((c) => c.id), ['c1', 'c2a', 'c2b', 'c3']);
        expect(_categorias.map((c) => c.id), original.map((c) => c.id));
      },
    );
  });

  group('CatalogoPublicoView - carga independiente de categorías', () {
    testWidgets(
      'carga categorías sin alterar productos, búsqueda, visibilidad ni carrito',
      (tester) async {
        var llamadasCategorias = 0;
        await _montar(
          tester,
          () async => _productos,
          cargarCategorias: () async {
            llamadasCategorias++;
            return _categorias;
          },
        );

        expect(llamadasCategorias, 1);
        expect(find.text('Pulsera Dorada'), findsOneWidget);
        expect(find.text('Collar Perla'), findsOneWidget);
        expect(find.text('Taza Grabada'), findsOneWidget);
        expect(find.text('Llavero Secreto'), findsNothing);

        await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
        await tester.pump();
        expect(
          find.text('"Pulsera Dorada" se agregó al carrito.'),
          findsOneWidget,
        );

        await _buscar(tester, 'perlas');
        expect(find.text('Collar Perla'), findsOneWidget);
        expect(find.text('Pulsera Dorada'), findsNothing);
      },
    );

    testWidgets(
      'muestra los productos normalmente aunque falle la carga de categorías',
      (tester) async {
        await _montar(
          tester,
          () async => _productos,
          cargarCategorias: () => Future.error(Exception('error categorías')),
        );

        expect(find.text('Pulsera Dorada'), findsOneWidget);
        expect(find.text('Collar Perla'), findsOneWidget);
        expect(find.text('Taza Grabada'), findsOneWidget);
        expect(find.text('Llavero Secreto'), findsNothing);
        expect(find.text('3 creaciones'), findsOneWidget);
      },
    );

    testWidgets(
      'ejecuta la carga de categorías aunque falle la carga de productos',
      (tester) async {
        var llamadasCategorias = 0;
        await _montar(
          tester,
          () => Future.error(Exception('error productos')),
          cargarCategorias: () async {
            llamadasCategorias++;
            return _categorias;
          },
        );

        expect(llamadasCategorias, 1);
        expect(
          find.text('No se pudieron cargar los productos en este momento.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });

  group('CatalogoPublicoView - filtros visuales por categoría (Etapa 4D)', () {
    final productos4D = <Producto>[
      _p(
        'p1',
        'Pulsera Mixta',
        descripcion: 'Acero y perlas',
        categoriaIds: ['c1', 'c2a'],
      ),
      _p(
        'p2',
        'Collar Clásico',
        descripcion: 'Baño de oro',
        categoriaIds: ['c2b'],
      ),
      _p('p3', 'Detalle Libre', descripcion: 'Sin categoría asignada'),
      _p(
        'p4',
        'Producto Oculto',
        visible: false,
        categoriaIds: ['c1', 'c3'],
      ),
    ];

    testWidgets(
      'muestra "Todos" seleccionado inicialmente y chips visibles ordenados',
      (tester) async {
        await _montar(
          tester,
          () async => productos4D,
          cargarCategorias: () async => _categorias,
        );

        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Pulseras'), findsOneWidget);
        expect(find.text('Aretes'), findsOneWidget);
        expect(find.text('Collares'), findsOneWidget);
        expect(find.text('Tazas'), findsOneWidget);
        expect(find.text('Oculta'), findsNothing);

        // Verifica orden administrativo: Pulseras (1), Aretes (2), Collares (2), Tazas (3).
        final xTodos = tester.getTopLeft(find.text('Todos')).dx;
        final xPulseras = tester.getTopLeft(find.text('Pulseras')).dx;
        final xAretes = tester.getTopLeft(find.text('Aretes')).dx;
        final xCollares = tester.getTopLeft(find.text('Collares')).dx;
        final xTazas = tester.getTopLeft(find.text('Tazas')).dx;
        expect(xTodos < xPulseras, isTrue);
        expect(xPulseras < xAretes, isTrue);
        expect(xAretes < xCollares, isTrue);
        expect(xCollares < xTazas, isTrue);

        // "Todos" muestra todos los productos visibles, incluso sin categorías.
        expect(find.text('Pulsera Mixta'), findsOneWidget);
        expect(find.text('Collar Clásico'), findsOneWidget);
        expect(find.text('Detalle Libre'), findsOneWidget);
        expect(find.text('Producto Oculto'), findsNothing);
        expect(find.text('3 creaciones'), findsOneWidget);
      },
    );

    testWidgets(
      'filtra por categoría, permite múltiples categorías sin duplicar y combina con búsqueda',
      (tester) async {
        await _montar(
          tester,
          () async => productos4D,
          cargarCategorias: () async => _categorias,
        );

        await tester.tap(find.text('Pulseras'));
        await tester.pump();

        expect(find.text('Pulsera Mixta'), findsOneWidget);
        expect(find.text('Collar Clásico'), findsNothing);
        expect(find.text('Detalle Libre'), findsNothing);
        expect(find.text('Producto Oculto'), findsNothing);
        expect(find.text('1 creación'), findsOneWidget);

        // El mismo producto en otra categoría asignada aparece sin duplicados.
        await tester.tap(find.text('Aretes'));
        await tester.pump();
        expect(find.text('Pulsera Mixta'), findsOneWidget);
        expect(find.text('1 creación'), findsOneWidget);

        // Combina categoría con búsqueda por nombre o descripción.
        await tester.tap(find.text('Collares'));
        await tester.pump();
        expect(find.text('Collar Clásico'), findsOneWidget);

        await _buscar(tester, 'oro');
        expect(find.text('Collar Clásico'), findsOneWidget);
        expect(find.text('1 creación'), findsOneWidget);

        await _buscar(tester, 'acero');
        expect(find.text('Collar Clásico'), findsNothing);
        expect(
          find.text('No encontramos productos que coincidan en esta categoría'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'categoría sin productos muestra mensaje adecuado y permite volver a "Todos"',
      (tester) async {
        await _montar(
          tester,
          () async => productos4D,
          cargarCategorias: () async => _categorias,
        );

        await tester.tap(find.text('Tazas'));
        await tester.pump();

        expect(find.text('No hay productos en esta categoría'), findsOneWidget);
        expect(find.text('Volver a Todos'), findsOneWidget);

        await tester.tap(find.text('Volver a Todos'));
        await tester.pump();

        expect(find.text('Pulsera Mixta'), findsOneWidget);
        expect(find.text('Collar Clásico'), findsOneWidget);
        expect(find.text('Detalle Libre'), findsOneWidget);
        expect(find.text('3 creaciones'), findsOneWidget);
      },
    );

    testWidgets(
      'conserva el contenido del carrito al cambiar de categoría y buscar',
      (tester) async {
        await _montar(
          tester,
          () async => productos4D,
          cargarCategorias: () async => _categorias,
        );

        await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
        await tester.pump();

        await tester.tap(find.text('Collares'));
        await tester.pump();
        await _buscar(tester, 'oro');

        await tester.tap(find.byIcon(Icons.shopping_bag_outlined).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Total del carrito'), findsOneWidget);
        expect(find.text('1 unidad agregada'), findsOneWidget);
        expect(find.text('Pulsera Mixta'), findsOneWidget);
      },
    );

    testWidgets(
      'si falla la carga de categorías mantiene "Todos", productos y permite reintentar',
      (tester) async {
        var intento = 0;
        await _montar(
          tester,
          () async => productos4D,
          cargarCategorias: () async {
            intento++;
            if (intento == 1) {
              throw Exception('sin conexión categorías');
            }
            return _categorias;
          },
        );

        expect(find.text('Todos'), findsOneWidget);
        expect(find.text('Pulsera Mixta'), findsOneWidget);
        expect(find.text('Collar Clásico'), findsOneWidget);
        expect(find.text('Detalle Libre'), findsOneWidget);
        expect(
          find.text('No se pudieron cargar las categorías.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);

        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(intento, 2);
        expect(
          find.text('No se pudieron cargar las categorías.'),
          findsNothing,
        );
        expect(find.text('Pulseras'), findsOneWidget);
        expect(find.text('Collares'), findsOneWidget);
      },
    );
  });
}
