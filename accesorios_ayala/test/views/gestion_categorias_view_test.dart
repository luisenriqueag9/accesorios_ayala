import 'package:accesorios_ayala/models/categoria.dart';
import 'package:accesorios_ayala/views/gestion_categorias_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget envolver(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }

  group('GestionCategoriasView', () {
    testWidgets('muestra el estado vacío cuando no hay categorías registradas', (
      tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          GestionCategoriasView(
            integrado: true,
            onCargarCategorias: () async => const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay categorías registradas'), findsOneWidget);
      expect(find.text('Crear primera categoría'), findsOneWidget);
    });

    testWidgets('valida nombre obligatorio y rechaza nombres solo con espacios', (
      tester,
    ) async {
      var llamadasGuardar = 0;

      await tester.pumpWidget(
        envolver(
          GestionCategoriasView(
            integrado: true,
            onCargarCategorias: () async => const [],
            onGuardarCategoria: (cat) async {
              llamadasGuardar++;
              return cat;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nueva categoría'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la categoría'),
        '   ',
      );
      await tester.tap(find.text('Crear categoría'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre es obligatorio.'), findsOneWidget);
      expect(llamadasGuardar, 0);
    });

    testWidgets('muestra categorías con su orden, estado visible/oculta y permite cambiar visibilidad', (
      tester,
    ) async {
      String? idActualizado;
      bool? visibilidadActualizada;

      await tester.pumpWidget(
        envolver(
          GestionCategoriasView(
            integrado: true,
            onCargarCategorias: () async => [
              Categoria(id: 'c1', nombre: 'Pulseras', orden: 1, visible: true),
              Categoria(id: 'c2', nombre: 'Aretes', orden: 2, visible: false),
            ],
            onCambiarVisibilidad: (id, visible) async {
              idActualizado = id;
              visibilidadActualizada = visible;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pulseras'), findsOneWidget);
      expect(find.text('Aretes'), findsOneWidget);
      expect(find.text('Orden 1'), findsOneWidget);
      expect(find.text('Orden 2'), findsOneWidget);
      expect(find.text('Visible'), findsOneWidget);
      expect(find.text('Oculta'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(idActualizado, 'c1');
      expect(visibilidadActualizada, isFalse);
      expect(find.text('Oculta'), findsNWidgets(2));
    });
  });
}
