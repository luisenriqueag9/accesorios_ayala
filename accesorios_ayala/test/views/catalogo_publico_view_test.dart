import 'package:accesorios_ayala/models/banner_config.dart';
import 'package:accesorios_ayala/models/categoria.dart';
import 'package:accesorios_ayala/models/producto.dart';
import 'package:accesorios_ayala/views/catalogo_publico_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController Function(Uri uri)? crearControladorVideo,
  Widget Function(VideoPlayerController controller)? construirVistaVideo,
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
        crearControladorVideo: crearControladorVideo,
        construirVistaVideo: construirVistaVideo,
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

  group('CatalogoPublicoView - carrusel de banner (Etapa 5D.5.4.2)', () {
    final configCarrusel3 = BannerConfig(
      activo: true,
      modo: ModoBannerCatalogo.carrusel,
      intervaloSegundos: 2,
      carrusel: const [
        BannerCarruselItem(
          id: 'c2',
          url: 'https://cdn.ejemplo.com/banner-2.jpg',
          orden: 2,
        ),
        BannerCarruselItem(
          id: 'c1',
          url: 'https://cdn.ejemplo.com/banner-1.jpg',
          orden: 1,
        ),
        BannerCarruselItem(
          id: 'c3',
          url: 'https://cdn.ejemplo.com/banner-3.jpg',
          orden: 3,
        ),
      ],
    );

    testWidgets(
      'muestra PageView con varias imágenes, rota según intervalo y regresa a la primera',
      (tester) async {
        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => configCarrusel3,
        );

        final pageViewFinder = find.byType(PageView);
        expect(pageViewFinder, findsOneWidget);

        final pageView = tester.widget<PageView>(pageViewFinder);
        final controller = pageView.controller!;
        expect(controller.page?.round(), 0);

        // Verifica que la primera diapositiva corresponde a orden 1.
        expect(
          find.descendant(
            of: pageViewFinder,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is NetworkImage &&
                  (w.image as NetworkImage).url ==
                      'https://cdn.ejemplo.com/banner-1.jpg',
            ),
          ),
          findsOneWidget,
        );

        // Avanza al índice 1 tras 2 segundos.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 600));
        expect(controller.page?.round(), 1);

        // Avanza al índice 2 tras otros 2 segundos.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 600));
        expect(controller.page?.round(), 2);

        // Regresa al índice 0 después de la última imagen.
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 600));
        expect(controller.page?.round(), 0);

        // Desmonta para verificar que el temporizador se cancele limpiamente.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('carrusel con una sola imagen no rota automáticamente', (
      tester,
    ) async {
      await _montar(
        tester,
        () async => _productos,
        cargarBanner: () async => BannerConfig(
          activo: true,
          modo: ModoBannerCatalogo.carrusel,
          intervaloSegundos: 2,
          carrusel: const [
            BannerCarruselItem(
              id: 'unica',
              url: 'https://cdn.ejemplo.com/unica.jpg',
              orden: 0,
            ),
          ],
        ),
      );

      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);
      final controller = tester.widget<PageView>(pageViewFinder).controller!;
      expect(controller.page?.round(), 0);

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.page?.round(), 0);
    });

    testWidgets(
      'carrusel desactivado o sin imágenes válidas muestra el respaldo estático',
      (tester) async {
        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: false,
            modo: ModoBannerCatalogo.carrusel,
            carrusel: configCarrusel3.carrusel,
          ),
        );

        expect(find.byType(PageView), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName ==
                    'assets/images/banner_pulsera_premium.png',
          ),
          findsOneWidget,
        );

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.carrusel,
            carrusel: const [],
          ),
        );

        expect(find.byType(PageView), findsNothing);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName ==
                    'assets/images/banner_pulsera_premium.png',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('cancela el temporizador del carrusel al desmontar la vista', (
      tester,
    ) async {
      await _montar(
        tester,
        () async => _productos,
        cargarBanner: () async => configCarrusel3,
      );

      expect(find.byType(PageView), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('CatalogoPublicoView - video de banner (Etapa 5D.5.5.2)', () {
    const urlVideoValida = 'https://cdn.ejemplo.com/promo-banner.mp4';
    const keyVideoWidget = ValueKey('video_banner_simulado');

    bool esImagenRespaldo(Widget w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName ==
            'assets/images/banner_pulsera_premium.png';

    testWidgets(
      'video activo con URL válida inicializa en orden, silencia, activa bucle y reproduce',
      (tester) async {
        _FakeVideoPlayerController? fakeCtrl;

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.video,
            videoUrl: urlVideoValida,
          ),
          crearControladorVideo: (uri) {
            fakeCtrl = _FakeVideoPlayerController();
            return fakeCtrl!;
          },
          construirVistaVideo: (_) => const SizedBox.expand(key: keyVideoWidget),
        );

        expect(fakeCtrl, isNotNull);
        expect(fakeCtrl!.llamadas, [
          'initialize',
          'setVolume:0.0',
          'setLooping:true',
          'play',
        ]);
        expect(find.byKey(keyVideoWidget), findsOneWidget);
        expect(find.byWidgetPredicate(esImagenRespaldo), findsNothing);
      },
    );

    testWidgets(
      'video desactivado muestra respaldo estático sin inicializar controlador',
      (tester) async {
        var invocaciones = 0;

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: false,
            modo: ModoBannerCatalogo.video,
            videoUrl: urlVideoValida,
          ),
          crearControladorVideo: (_) {
            invocaciones++;
            return _FakeVideoPlayerController();
          },
          construirVistaVideo: (_) => const SizedBox.expand(key: keyVideoWidget),
        );

        expect(invocaciones, 0);
        expect(find.byKey(keyVideoWidget), findsNothing);
        expect(find.byWidgetPredicate(esImagenRespaldo), findsOneWidget);
      },
    );

    testWidgets(
      'URL inválida o ausente muestra respaldo estático sin inicializar video',
      (tester) async {
        var invocaciones = 0;

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.video,
            videoUrl: '/ruta-relativa-invalida.mp4',
          ),
          crearControladorVideo: (_) {
            invocaciones++;
            return _FakeVideoPlayerController();
          },
          construirVistaVideo: (_) => const SizedBox.expand(key: keyVideoWidget),
        );

        expect(invocaciones, 0);
        expect(find.byKey(keyVideoWidget), findsNothing);
        expect(find.byWidgetPredicate(esImagenRespaldo), findsOneWidget);
      },
    );

    testWidgets(
      'error de inicialización mantiene el respaldo estático y libera el controlador',
      (tester) async {
        _FakeVideoPlayerController? fakeCtrl;

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.video,
            videoUrl: urlVideoValida,
          ),
          crearControladorVideo: (_) {
            fakeCtrl = _FakeVideoPlayerController(fallarInitialize: true);
            return fakeCtrl!;
          },
          construirVistaVideo: (_) => const SizedBox.expand(key: keyVideoWidget),
        );

        expect(fakeCtrl, isNotNull);
        expect(fakeCtrl!.disposed, isTrue);
        expect(find.byKey(keyVideoWidget), findsNothing);
        expect(find.byWidgetPredicate(esImagenRespaldo), findsOneWidget);
      },
    );

    testWidgets(
      'fallo de reproducción automática mantiene el respaldo estático y libera el controlador',
      (tester) async {
        _FakeVideoPlayerController? fakeCtrl;

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.video,
            videoUrl: urlVideoValida,
          ),
          crearControladorVideo: (_) {
            fakeCtrl = _FakeVideoPlayerController(fallarPlay: true);
            return fakeCtrl!;
          },
          construirVistaVideo: (_) => const SizedBox.expand(key: keyVideoWidget),
        );

        expect(fakeCtrl, isNotNull);
        expect(fakeCtrl!.disposed, isTrue);
        expect(find.byKey(keyVideoWidget), findsNothing);
        expect(find.byWidgetPredicate(esImagenRespaldo), findsOneWidget);
      },
    );

    testWidgets(
      'modos Imagen fija y Carrusel no inicializan el controlador de video',
      (tester) async {
        var invocaciones = 0;

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.imagen,
            imagenUrl: 'https://cdn.ejemplo.com/banner.jpg',
            videoUrl: urlVideoValida,
          ),
          crearControladorVideo: (_) {
            invocaciones++;
            return _FakeVideoPlayerController();
          },
        );
        expect(invocaciones, 0);

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.carrusel,
            videoUrl: urlVideoValida,
            carrusel: const [
              BannerCarruselItem(
                id: 'c1',
                url: 'https://cdn.ejemplo.com/1.jpg',
                orden: 0,
              ),
            ],
          ),
          crearControladorVideo: (_) {
            invocaciones++;
            return _FakeVideoPlayerController();
          },
        );
        expect(invocaciones, 0);
      },
    );

    testWidgets(
      'libera el controlador de video al desmontar la vista',
      (tester) async {
        _FakeVideoPlayerController? fakeCtrl;

        await _montar(
          tester,
          () async => _productos,
          cargarBanner: () async => BannerConfig(
            activo: true,
            modo: ModoBannerCatalogo.video,
            videoUrl: urlVideoValida,
          ),
          crearControladorVideo: (_) {
            fakeCtrl = _FakeVideoPlayerController();
            return fakeCtrl!;
          },
          construirVistaVideo: (_) => const SizedBox.expand(key: keyVideoWidget),
        );

        expect(fakeCtrl, isNotNull);
        expect(fakeCtrl!.disposed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(fakeCtrl!.disposed, isTrue);
      },
    );
  });
}

class _FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  final bool fallarInitialize;
  final bool fallarPlay;
  final List<String> llamadas = [];
  bool disposed = false;

  _FakeVideoPlayerController({
    this.fallarInitialize = false,
    this.fallarPlay = false,
  }) : super(const VideoPlayerValue.uninitialized());

  @override
  Future<void> initialize() async {
    llamadas.add('initialize');
    if (fallarInitialize) {
      throw Exception('error initialize');
    }
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 5),
      size: const Size(1280, 720),
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    llamadas.add('setVolume:$volume');
    value = value.copyWith(volume: volume);
  }

  @override
  Future<void> setLooping(bool looping) async {
    llamadas.add('setLooping:$looping');
    value = value.copyWith(isLooping: looping);
  }

  @override
  Future<void> play() async {
    llamadas.add('play');
    if (fallarPlay) {
      throw Exception('error play');
    }
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
