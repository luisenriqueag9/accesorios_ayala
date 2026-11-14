import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:accesorios_ayala/controllers/auth_controller.dart';
import 'package:accesorios_ayala/views/login_view.dart';

void main() {
  Widget construirVistaLogin() {
    return const MaterialApp(
      home: LoginView(),
    );
  }

  Finder campoCorreoFinder() {
    return find.widgetWithText(TextField, 'Correo electrónico');
  }

  TextField obtenerCampoCorreo(WidgetTester tester) {
    return tester.widget<TextField>(campoCorreoFinder());
  }

  Checkbox obtenerCheckboxRecordar(WidgetTester tester) {
    return tester.widget<Checkbox>(find.byType(Checkbox));
  }

  group('LoginView - Recordar mi correo', () {
    testWidgets(
      'precarga el último correo cuando hay correo guardado y la preferencia está activada',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'admin_ultimo_correo': 'admin@accesoriosayala.com',
          'admin_recordar_correo': true,
        });

        await tester.pumpWidget(construirVistaLogin());
        await tester.pumpAndSettle();

        expect(
          obtenerCampoCorreo(tester).controller?.text,
          'admin@accesoriosayala.com',
        );
        expect(obtenerCheckboxRecordar(tester).value, isTrue);
      },
    );

    testWidgets(
      'muestra el campo vacío y la casilla activada por defecto cuando no hay correo guardado',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(construirVistaLogin());
        await tester.pumpAndSettle();

        expect(obtenerCampoCorreo(tester).controller?.text, isEmpty);
        expect(obtenerCheckboxRecordar(tester).value, isTrue);
      },
    );

    testWidgets(
      'no precarga el correo cuando la preferencia está desactivada',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'admin_ultimo_correo': 'admin@accesoriosayala.com',
          'admin_recordar_correo': false,
        });

        await tester.pumpWidget(construirVistaLogin());
        await tester.pumpAndSettle();

        expect(obtenerCampoCorreo(tester).controller?.text, isEmpty);
        expect(obtenerCheckboxRecordar(tester).value, isFalse);
      },
    );

    testWidgets(
      'desactivar la casilla elimina el correo guardado y reactivarla no lo restaura',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'admin_ultimo_correo': 'admin@accesoriosayala.com',
          'admin_recordar_correo': true,
        });

        await tester.pumpWidget(construirVistaLogin());
        await tester.pumpAndSettle();

        expect(obtenerCheckboxRecordar(tester).value, isTrue);

        await tester.tap(find.text('Recordar mi correo'));
        await tester.pumpAndSettle();

        expect(obtenerCheckboxRecordar(tester).value, isFalse);
        expect(await AuthController.obtenerPreferenciaRecordarCorreo(), isFalse);
        expect(await AuthController.obtenerUltimoCorreoGuardado(), isNull);

        // Volver a activar no restaura el correo previamente eliminado
        await tester.tap(find.text('Recordar mi correo'));
        await tester.pumpAndSettle();

        expect(obtenerCheckboxRecordar(tester).value, isTrue);
        expect(await AuthController.obtenerPreferenciaRecordarCorreo(), isTrue);
        expect(await AuthController.obtenerUltimoCorreoGuardado(), isNull);
      },
    );

    testWidgets(
      'conserva la preferencia desactivada al reconstruir la pantalla',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'admin_ultimo_correo': 'admin@accesoriosayala.com',
          'admin_recordar_correo': true,
        });

        await tester.pumpWidget(construirVistaLogin());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Recordar mi correo'));
        await tester.pumpAndSettle();

        // Desmontar y volver a montar LoginView simulando reapertura
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpWidget(construirVistaLogin());
        await tester.pumpAndSettle();

        expect(obtenerCheckboxRecordar(tester).value, isFalse);
        expect(obtenerCampoCorreo(tester).controller?.text, isEmpty);
      },
    );

    testWidgets(
      'permite escribir o borrar el correo manualmente',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'admin_ultimo_correo': 'inicial@accesoriosayala.com',
          'admin_recordar_correo': true,
        });

        await tester.pumpWidget(construirVistaLogin());
        await tester.pumpAndSettle();

        expect(
          obtenerCampoCorreo(tester).controller?.text,
          'inicial@accesoriosayala.com',
        );

        await tester.enterText(
          campoCorreoFinder(),
          'otro@accesoriosayala.com',
        );
        await tester.pump();
        expect(
          obtenerCampoCorreo(tester).controller?.text,
          'otro@accesoriosayala.com',
        );

        await tester.enterText(campoCorreoFinder(), '');
        await tester.pump();
        expect(obtenerCampoCorreo(tester).controller?.text, isEmpty);
      },
    );

    testWidgets(
      'la carga asíncrona no sobrescribe el correo que el usuario ya escribió',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'admin_ultimo_correo': 'guardado@accesoriosayala.com',
          'admin_recordar_correo': true,
        });

        // Primer frame sin completar aún los futures asíncronos de SharedPreferences
        await tester.pumpWidget(construirVistaLogin());
        await tester.enterText(
          campoCorreoFinder(),
          'manual@accesoriosayala.com',
        );
        await tester.pumpAndSettle();

        expect(
          obtenerCampoCorreo(tester).controller?.text,
          'manual@accesoriosayala.com',
        );
      },
    );
  });
}
