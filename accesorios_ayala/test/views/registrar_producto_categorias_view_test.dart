import 'package:accesorios_ayala/models/categoria.dart';
import 'package:accesorios_ayala/models/producto.dart';
import 'package:accesorios_ayala/views/registrar_producto_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _categorias = <Categoria>[
  Categoria(id: 'idPulseras', nombre: 'Pulseras', orden: 1),
  Categoria(id: 'idCollares', nombre: 'Collares', orden: 2),
  Categoria(id: 'idGraduacion', nombre: 'Graduación', orden: 3),
  Categoria(id: 'idOculta', nombre: 'Temporada', orden: 4, visible: false),
];

Producto _producto({List<String> categoriaIds = const []}) => Producto(
  id: 'prod-1',
  nombre: 'Pulsera Dorada',
  descripcion: 'Acero inoxidable',
  precio: 250.0,
  imageUrl: 'https://ejemplo.com/pulsera.jpg',
  visibleCatalogo: false,
  categoriaIds: categoriaIds,
);

Finder _chip(String id) => find.byKey(ValueKey('chip-categoria-$id'));

bool _seleccionado(WidgetTester tester, String id) =>
    tester.widget<FilterChip>(_chip(id)).selected;

class _Arnes {
  final guardados = <Producto>[];
  int llamadasCarga = 0;
}

Future<_Arnes> _montar(
  WidgetTester tester, {
  Producto? producto,
  Future<List<Categoria>> Function(int intento)? cargar,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final arnes = _Arnes();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RegistrarProductoView(
            key: UniqueKey(),
            producto: producto,
            integrado: true,
            onGuardado: () {},
            cargarCategorias: () {
              arnes.llamadasCarga++;
              return cargar != null
                  ? cargar(arnes.llamadasCarga)
                  : Future.value(_categorias);
            },
            guardarProducto: (p) async => arnes.guardados.add(p),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return arnes;
}

Future<void> _guardar(WidgetTester tester) async {
  await tester.tap(find.text('Actualizar producto'));
  await tester.pumpAndSettle();
}

void main() {
  group('RegistrarProductoView - categorías', () {
    testWidgets('muestra las categorías visibles en orden y sin las ocultas', (
      tester,
    ) async {
      final arnes = await _montar(tester, producto: _producto());

      expect(arnes.llamadasCarga, 1);
      expect(find.text('Categorías'), findsOneWidget);
      for (final id in ['idPulseras', 'idCollares', 'idGraduacion']) {
        expect(_chip(id), findsOneWidget);
        expect(_seleccionado(tester, id), isFalse);
      }
      expect(_chip('idOculta'), findsNothing);

      final x1 = tester.getTopLeft(_chip('idPulseras')).dx;
      final x2 = tester.getTopLeft(_chip('idCollares')).dx;
      final x3 = tester.getTopLeft(_chip('idGraduacion')).dx;
      expect(x1 < x2 && x2 < x3, isTrue);
    });

    testWidgets('permite seleccionar varias categorías y las guarda', (
      tester,
    ) async {
      final arnes = await _montar(tester, producto: _producto());

      await tester.tap(_chip('idPulseras'));
      await tester.pump();
      await tester.tap(_chip('idGraduacion'));
      await tester.pump();

      expect(_seleccionado(tester, 'idPulseras'), isTrue);
      expect(_seleccionado(tester, 'idGraduacion'), isTrue);
      expect(_seleccionado(tester, 'idCollares'), isFalse);

      await _guardar(tester);
      expect(arnes.guardados, hasLength(1));
      expect(arnes.guardados.single.categoriaIds, [
        'idPulseras',
        'idGraduacion',
      ]);
    });

    testWidgets('permite desmarcar una categoría seleccionada', (tester) async {
      final arnes = await _montar(
        tester,
        producto: _producto(categoriaIds: ['idPulseras', 'idCollares']),
      );

      await tester.tap(_chip('idPulseras'));
      await tester.pump();
      expect(_seleccionado(tester, 'idPulseras'), isFalse);

      await _guardar(tester);
      expect(arnes.guardados.single.categoriaIds, ['idCollares']);
    });

    testWidgets(
      'conserva las categorías existentes y los demás campos al editar sin cambios',
      (tester) async {
        final arnes = await _montar(
          tester,
          producto: _producto(categoriaIds: ['idCollares', 'idPulseras']),
        );

        expect(_seleccionado(tester, 'idCollares'), isTrue);
        expect(_seleccionado(tester, 'idPulseras'), isTrue);

        await _guardar(tester);
        final g = arnes.guardados.single;
        expect(g.categoriaIds, ['idCollares', 'idPulseras']);
        expect(g.id, 'prod-1');
        expect(g.nombre, 'Pulsera Dorada');
        expect(g.descripcion, 'Acero inoxidable');
        expect(g.precio, 250.0);
        expect(g.imageUrl, 'https://ejemplo.com/pulsera.jpg');
        expect(g.visibleCatalogo, isFalse);
      },
    );

    testWidgets(
      'muestra una categoría oculta asignada como "Oculta" y la conserva',
      (tester) async {
        final arnes = await _montar(
          tester,
          producto: _producto(categoriaIds: ['idOculta']),
        );

        expect(_chip('idOculta'), findsOneWidget);
        expect(_seleccionado(tester, 'idOculta'), isTrue);
        expect(
          find.descendant(of: _chip('idOculta'), matching: find.text('Oculta')),
          findsOneWidget,
        );

        await _guardar(tester);
        expect(arnes.guardados.single.categoriaIds, ['idOculta']);
      },
    );

    testWidgets(
      'no permite asignar una categoría oculta nueva, ni re-agregarla al desmarcarla',
      (tester) async {
        final sinOculta = await _montar(tester, producto: _producto());
        expect(_chip('idOculta'), findsNothing);
        expect(find.text('Temporada'), findsNothing);
        expect(sinOculta.llamadasCarga, 1);

        final arnes = await _montar(
          tester,
          producto: _producto(categoriaIds: ['idOculta']),
        );
        await tester.tap(_chip('idOculta'));
        await tester.pump();
        expect(_chip('idOculta'), findsNothing);

        await _guardar(tester);
        expect(arnes.guardados.single.categoriaIds, isEmpty);
      },
    );

    testWidgets('conserva IDs de categorías no disponibles', (tester) async {
      final arnes = await _montar(
        tester,
        producto: _producto(categoriaIds: ['idPulseras', 'idBorrada']),
      );

      expect(_chip('idBorrada'), findsOneWidget);
      expect(_seleccionado(tester, 'idBorrada'), isTrue);
      expect(find.text('Categoría no disponible'), findsOneWidget);

      await _guardar(tester);
      expect(arnes.guardados.single.categoriaIds, ['idPulseras', 'idBorrada']);
    });

    testWidgets('mantiene la selección si falla la carga y permite guardar', (
      tester,
    ) async {
      final arnes = await _montar(
        tester,
        producto: _producto(categoriaIds: ['idPulseras', 'idOculta']),
        cargar: (_) => Future.error(Exception('sin conexión')),
      );

      expect(find.textContaining('No se pudieron cargar'), findsOneWidget);
      expect(find.textContaining('Se conservarán las 2'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);

      // El resto del formulario sigue operativo.
      await _guardar(tester);
      expect(arnes.guardados.single.categoriaIds, ['idPulseras', 'idOculta']);
    });

    testWidgets('permite reintentar después de un error', (tester) async {
      final arnes = await _montar(
        tester,
        producto: _producto(categoriaIds: ['idCollares']),
        cargar: (intento) => intento == 1
            ? Future.error(Exception('fallo temporal'))
            : Future.value(_categorias),
      );

      expect(find.byKey(const ValueKey('btn-reintentar-categorias')),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('btn-reintentar-categorias')));
      await tester.pumpAndSettle();

      expect(arnes.llamadasCarga, 2);
      expect(find.textContaining('No se pudieron cargar'), findsNothing);
      expect(_seleccionado(tester, 'idCollares'), isTrue);
      expect(_seleccionado(tester, 'idPulseras'), isFalse);
    });

    testWidgets(
      'no modifica categorías sin acción explícita, aun tras reintentar la carga',
      (tester) async {
        final original = ['idGraduacion', 'idOculta', 'idBorrada'];
        final arnes = await _montar(
          tester,
          producto: _producto(categoriaIds: original),
          cargar: (intento) => intento == 1
              ? Future.error(Exception('fallo'))
              : Future.value(_categorias),
        );

        await tester.tap(
          find.byKey(const ValueKey('btn-reintentar-categorias')),
        );
        await tester.pumpAndSettle();

        // Cambiar otros campos no debe tocar las categorías.
        await tester.enterText(
          find.widgetWithText(TextField, 'Pulsera Dorada'),
          'Pulsera Plateada',
        );
        await tester.pump();

        await _guardar(tester);
        final g = arnes.guardados.single;
        expect(g.nombre, 'Pulsera Plateada');
        expect(g.categoriaIds, original);
      },
    );
  });
}
