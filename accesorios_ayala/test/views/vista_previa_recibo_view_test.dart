import 'dart:async';
import 'dart:typed_data';

import 'package:accesorios_ayala/models/cliente.dart';
import 'package:accesorios_ayala/models/producto.dart';
import 'package:accesorios_ayala/models/venta.dart';
import 'package:accesorios_ayala/views/vista_previa_recibo_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final clientePrueba = Cliente(
    id: 'cli-1',
    nombre: 'María López',
    telefono: '9999-8888',
    direccion: 'Colonia Centro, Casa 12',
    departamento: 'Francisco Morazán',
  );

  final productoPrueba = Producto(
    id: 'prod-1',
    nombre: 'Aretes Dorados',
    descripcion: 'Aretes bañados en oro',
    precio: 100.0,
  );

  final productosPrueba = <Map<String, dynamic>>[
    {
      'producto': productoPrueba,
      'cantidad': 2,
    },
  ];

  final ventaHistoricaPrueba = Venta(
    id: 'FAC-0042',
    clienteId: 'cli-1',
    clienteNombre: 'María López',
    fecha: DateTime(2026, 3, 15, 10, 30),
    subtotal: 350.00,
    impuesto: 47.25,
    total: 512.25,
    envio: 150.00,
    descuentoMayoristaActivo: true,
    descuentoPorcentaje: 10.0,
    descuentoMonto: 35.00,
  );

  void configurarPantallaEscritorio(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget envolver(Widget child) {
    return MaterialApp(home: child);
  }

  group('VistaPreviaReciboView', () {
    testWidgets(
      'muestra el número y la fecha originales de una factura histórica',
      (tester) async {
        configurarPantallaEscritorio(tester);
        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Factura #FAC-0042'), findsOneWidget);
        expect(find.text('Fecha de emisión: 15/03/2026'), findsOneWidget);
        expect(find.text('Solo lectura'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra los importes y total reales de la factura histórica aunque difieran del recálculo',
      (tester) async {
        configurarPantallaEscritorio(tester);
        // productosPrueba suma Lps 200.00, pero ventaHistoricaPrueba persiste
        // subtotal 350.00, descuento 35.00, impuesto 47.25, envío 150.00 y total 512.25.
        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final resumen = find
            .ancestor(of: find.text('Resumen'), matching: find.byType(Column))
            .first;

        expect(
          find.descendant(of: resumen, matching: find.text('Lps 350.00')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: resumen, matching: find.text('- Lps 35.00')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: resumen, matching: find.text('Lps 47.25')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: resumen, matching: find.text('Lps 150.00')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: resumen, matching: find.text('Lps 512.25')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: resumen, matching: find.text('Lps 200.00')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'bloquea la edición de descuento, impuesto y envío en modo soloLectura',
      (tester) async {
        configurarPantallaEscritorio(tester);
        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isTrue);
        expect(switchWidget.onChanged, isNull);

        final campos = tester.widgetList<TextField>(find.byType(TextField));
        expect(campos.length, 3);
        for (final campo in campos) {
          expect(campo.enabled, isFalse);
        }
      },
    );

    testWidgets(
      'exige número y fecha válidos en modo soloLectura y muestra aviso de no guardado',
      (tester) async {
        configurarPantallaEscritorio(tester);
        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
            ),
          ),
        );

        expect(tester.takeException(), isArgumentError);

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Descargar PDF'), findsOneWidget);
        final botonPdf = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Descargar PDF'),
            matching: find.byWidgetPredicate((w) => w is ElevatedButton),
          ),
        );
        expect(botonPdf.onPressed, isNotNull);
        expect(
          find.text(
            'Factura histórica #FAC-0042 (15/03/2026). Descarga disponible con los importes originales, sin modificar registros.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'conserva el comportamiento actual del modo manual cuando soloLectura es false',
      (tester) async {
        configurarPantallaEscritorio(tester);
        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Solo lectura'), findsNothing);

        final resumen = find
            .ancestor(of: find.text('Resumen'), matching: find.byType(Column))
            .first;
        expect(
          find.descendant(of: resumen, matching: find.text('Lps 200.00')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: resumen, matching: find.text('Lps 320.00')),
          findsOneWidget,
        );

        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.value, isFalse);
        expect(switchWidget.onChanged, isNotNull);

        final campos = tester.widgetList<TextField>(find.byType(TextField));
        expect(campos.length, 2);
        for (final campo in campos) {
          expect(campo.enabled, isTrue);
        }

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: resumen, matching: find.text('- Lps 40.00')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: resumen, matching: find.text('Lps 280.00')),
          findsOneWidget,
        );

        final botonPdf = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Descargar PDF'),
            matching: find.byWidgetPredicate((w) => w is ElevatedButton),
          ),
        );
        expect(botonPdf.onPressed, isNotNull);
      },
    );

    testWidgets(
      'renderiza una factura histórica válida sin errores en modo integrado',
      (tester) async {
        configurarPantallaEscritorio(tester);
        await tester.pumpWidget(
          envolver(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: VistaPreviaReciboView(
                  cliente: clientePrueba,
                  seleccionados: productosPrueba,
                  integrado: true,
                  onVolver: () {},
                  soloLectura: true,
                  ventaHistorica: ventaHistoricaPrueba,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Vista previa de factura'), findsOneWidget);
        expect(find.text('Factura #FAC-0042'), findsOneWidget);
        expect(find.text('Lps 512.25'), findsOneWidget);
      },
    );

    testWidgets(
      'descarga PDF histórico con importes, número y fecha originales sin guardar venta ni permitir doble pulsación',
      (tester) async {
        configurarPantallaEscritorio(tester);
        final completer = Completer<Uint8List>();
        var llamadasGenerador = 0;
        var llamadasGuardar = 0;
        String? facturaRecibida;
        DateTime? fechaRecibida;
        double? subtotalRecibido;
        double? descuentoRecibido;
        double? impuestoRecibido;
        double? totalRecibido;
        double? envioRecibido;
        String? nombreArchivoDescargado;
        Uint8List? bytesDescargados;

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
              onGuardarVenta: (_) async {
                llamadasGuardar++;
              },
              onGenerarPdf: ({
                required cliente,
                required seleccionados,
                required impuestoPorcentaje,
                envio = 0.0,
                descuentoMayoristaActivo = false,
                descuentoPorcentaje = 0.0,
                facturaNumero,
                fechaEmision,
                subtotalOverride,
                descuentoMontoOverride,
                impuestoOverride,
                totalOverride,
              }) {
                llamadasGenerador++;
                facturaRecibida = facturaNumero;
                fechaRecibida = fechaEmision;
                subtotalRecibido = subtotalOverride;
                descuentoRecibido = descuentoMontoOverride;
                impuestoRecibido = impuestoOverride;
                totalRecibido = totalOverride;
                envioRecibido = envio;
                return completer.future;
              },
              onDescargarPdf: (bytes, nombreArchivo) {
                bytesDescargados = bytes;
                nombreArchivoDescargado = nombreArchivo;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Descargar PDF'));
        await tester.pump();

        // Mientras procesa, una segunda pulsación no dispara otra generación.
        expect(find.text('Procesando...'), findsOneWidget);
        await tester.tap(find.text('Procesando...'), warnIfMissed: false);
        await tester.pump();
        expect(llamadasGenerador, 1);

        final pdfSimulado = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
        completer.complete(pdfSimulado);
        await tester.pumpAndSettle();

        expect(llamadasGuardar, 0);
        expect(facturaRecibida, 'FAC-0042');
        expect(fechaRecibida, ventaHistoricaPrueba.fecha.toLocal());
        expect(subtotalRecibido, 350.00);
        expect(descuentoRecibido, 35.00);
        expect(impuestoRecibido, 47.25);
        expect(totalRecibido, 512.25);
        expect(envioRecibido, 150.00);
        expect(nombreArchivoDescargado, 'Factura_FAC-0042.pdf');
        expect(bytesDescargados, pdfSimulado);
      },
    );

    testWidgets(
      'descarga PDF manual sin overrides y mantiene el guardado de venta',
      (tester) async {
        configurarPantallaEscritorio(tester);
        var llamadasGuardar = 0;
        double? subtotalOverrideRecibido = -1;
        double? totalOverrideRecibido = -1;
        String? nombreArchivoDescargado;

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              onGuardarVenta: (_) async {
                llamadasGuardar++;
              },
              onGenerarPdf: ({
                required cliente,
                required seleccionados,
                required impuestoPorcentaje,
                envio = 0.0,
                descuentoMayoristaActivo = false,
                descuentoPorcentaje = 0.0,
                facturaNumero,
                fechaEmision,
                subtotalOverride,
                descuentoMontoOverride,
                impuestoOverride,
                totalOverride,
              }) async {
                subtotalOverrideRecibido = subtotalOverride;
                totalOverrideRecibido = totalOverride;
                return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
              },
              onDescargarPdf: (_, nombreArchivo) {
                nombreArchivoDescargado = nombreArchivo;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Descargar PDF'));
        await tester.pumpAndSettle();

        expect(llamadasGuardar, 1);
        expect(subtotalOverrideRecibido, isNull);
        expect(totalOverrideRecibido, isNull);
        expect(
          nombreArchivoDescargado,
          startsWith('Recibo_AccesoriosAyala_'),
        );
        expect(nombreArchivoDescargado, endsWith('.pdf'));
      },
    );

    test('normaliza teléfonos hondureños y rechaza inválidos', () {
      expect(
        VistaPreviaReciboView.normalizarTelefonoWhatsApp('9999-8888'),
        '50499998888',
      );
      expect(
        VistaPreviaReciboView.normalizarTelefonoWhatsApp('504 9999 8888'),
        '50499998888',
      );
      expect(
        VistaPreviaReciboView.normalizarTelefonoWhatsApp('+504 (9999)-8888'),
        '50499998888',
      );
      expect(VistaPreviaReciboView.normalizarTelefonoWhatsApp(''), isNull);
      expect(VistaPreviaReciboView.normalizarTelefonoWhatsApp('   '), isNull);
      expect(
        VistaPreviaReciboView.normalizarTelefonoWhatsApp('9999888'),
        isNull,
      );
      expect(
        VistaPreviaReciboView.normalizarTelefonoWhatsApp('+1 555 123 4567'),
        isNull,
      );
    });

    testWidgets(
      'muestra Compartir por WhatsApp solo en modo histórico y lo oculta en modo manual',
      (tester) async {
        configurarPantallaEscritorio(tester);

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Compartir por WhatsApp'), findsOneWidget);

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Compartir por WhatsApp'), findsNothing);
      },
    );

    testWidgets(
      'comparte factura histórica por WhatsApp reutilizando bytes, descargando Factura_FAC y sin guardar venta',
      (tester) async {
        configurarPantallaEscritorio(tester);
        var llamadasGenerador = 0;
        var llamadasGuardar = 0;
        final archivosDescargados = <String>[];
        Uri? urlWhatsapp;
        final pdfSimulado = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
              onGuardarVenta: (_) async {
                llamadasGuardar++;
              },
              onGenerarPdf: ({
                required cliente,
                required seleccionados,
                required impuestoPorcentaje,
                envio = 0.0,
                descuentoMayoristaActivo = false,
                descuentoPorcentaje = 0.0,
                facturaNumero,
                fechaEmision,
                subtotalOverride,
                descuentoMontoOverride,
                impuestoOverride,
                totalOverride,
              }) async {
                llamadasGenerador++;
                return pdfSimulado;
              },
              onDescargarPdf: (_, nombreArchivo) {
                archivosDescargados.add(nombreArchivo);
              },
              onAbrirWhatsapp: (url) async {
                urlWhatsapp = url;
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Primera acción: Descargar PDF genera y cachea los bytes.
        await tester.tap(find.text('Descargar PDF'));
        await tester.pumpAndSettle();
        expect(llamadasGenerador, 1);

        // Segunda acción: Compartir por WhatsApp reutiliza _pdfBytesEmitido.
        await tester.tap(find.text('Compartir por WhatsApp'));
        await tester.pumpAndSettle();

        expect(llamadasGenerador, 1);
        expect(llamadasGuardar, 0);
        expect(archivosDescargados, [
          'Factura_FAC-0042.pdf',
          'Factura_FAC-0042.pdf',
        ]);
        expect(urlWhatsapp, isNotNull);
        expect(urlWhatsapp!.scheme, 'https');
        expect(urlWhatsapp!.host, 'wa.me');
        expect(urlWhatsapp!.path, '/50499998888');
        final texto = urlWhatsapp!.queryParameters['text'] ?? '';
        expect(texto, contains('FAC-0042'));
        expect(texto, contains('L. 512.25'));
        expect(texto, isNot(contains('Adjuntamos')));
        expect(
          find.textContaining('Adjunta el PDF descargado'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'rechaza teléfono inválido antes de generar PDF o abrir WhatsApp',
      (tester) async {
        configurarPantallaEscritorio(tester);
        var llamadasGenerador = 0;
        var llamadasDescargar = 0;
        var llamadasWhatsapp = 0;

        final clienteSinTelefonoValido = Cliente(
          id: 'cli-2',
          nombre: 'Cliente Sin Tel',
          telefono: '123',
          direccion: 'Col. Centro',
          departamento: 'Cortés',
        );

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clienteSinTelefonoValido,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
              onGenerarPdf: ({
                required cliente,
                required seleccionados,
                required impuestoPorcentaje,
                envio = 0.0,
                descuentoMayoristaActivo = false,
                descuentoPorcentaje = 0.0,
                facturaNumero,
                fechaEmision,
                subtotalOverride,
                descuentoMontoOverride,
                impuestoOverride,
                totalOverride,
              }) async {
                llamadasGenerador++;
                return Uint8List(0);
              },
              onDescargarPdf: (_, __) {
                llamadasDescargar++;
              },
              onAbrirWhatsapp: (_) async {
                llamadasWhatsapp++;
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Compartir por WhatsApp'));
        await tester.pumpAndSettle();

        expect(llamadasGenerador, 0);
        expect(llamadasDescargar, 0);
        expect(llamadasWhatsapp, 0);
        expect(
          find.text(
            'El cliente no tiene un número de teléfono válido para WhatsApp (+504).',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'bloquea pulsaciones simultáneas al compartir por WhatsApp',
      (tester) async {
        configurarPantallaEscritorio(tester);
        final completer = Completer<Uint8List>();
        var llamadasGenerador = 0;
        var llamadasWhatsapp = 0;

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
              onGenerarPdf: ({
                required cliente,
                required seleccionados,
                required impuestoPorcentaje,
                envio = 0.0,
                descuentoMayoristaActivo = false,
                descuentoPorcentaje = 0.0,
                facturaNumero,
                fechaEmision,
                subtotalOverride,
                descuentoMontoOverride,
                impuestoOverride,
                totalOverride,
              }) {
                llamadasGenerador++;
                return completer.future;
              },
              onDescargarPdf: (_, __) {},
              onAbrirWhatsapp: (_) async {
                llamadasWhatsapp++;
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Compartir por WhatsApp'));
        await tester.pump();
        await tester.tap(
          find.text('Compartir por WhatsApp'),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(llamadasGenerador, 1);

        completer.complete(Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]));
        await tester.pumpAndSettle();

        expect(llamadasWhatsapp, 1);
      },
    );

    testWidgets(
      'si falla la generación del PDF histórico, informa el error y no abre WhatsApp',
      (tester) async {
        configurarPantallaEscritorio(tester);
        var llamadasWhatsapp = 0;

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
              onGenerarPdf: ({
                required cliente,
                required seleccionados,
                required impuestoPorcentaje,
                envio = 0.0,
                descuentoMayoristaActivo = false,
                descuentoPorcentaje = 0.0,
                facturaNumero,
                fechaEmision,
                subtotalOverride,
                descuentoMontoOverride,
                impuestoOverride,
                totalOverride,
              }) async {
                throw StateError('fallo pdf');
              },
              onDescargarPdf: (_, __) {},
              onAbrirWhatsapp: (_) async {
                llamadasWhatsapp++;
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Compartir por WhatsApp'));
        await tester.pumpAndSettle();

        expect(llamadasWhatsapp, 0);
        expect(
          find.text('Error al preparar la factura para WhatsApp'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'si falla la apertura de WhatsApp, informa el error sin afirmar envío',
      (tester) async {
        configurarPantallaEscritorio(tester);
        var llamadasWhatsapp = 0;

        await tester.pumpWidget(
          envolver(
            VistaPreviaReciboView(
              cliente: clientePrueba,
              seleccionados: productosPrueba,
              soloLectura: true,
              ventaHistorica: ventaHistoricaPrueba,
              onGenerarPdf: ({
                required cliente,
                required seleccionados,
                required impuestoPorcentaje,
                envio = 0.0,
                descuentoMayoristaActivo = false,
                descuentoPorcentaje = 0.0,
                facturaNumero,
                fechaEmision,
                subtotalOverride,
                descuentoMontoOverride,
                impuestoOverride,
                totalOverride,
              }) async {
                return Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);
              },
              onDescargarPdf: (_, __) {},
              onAbrirWhatsapp: (_) async {
                llamadasWhatsapp++;
                return false;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Compartir por WhatsApp'));
        await tester.pumpAndSettle();

        expect(llamadasWhatsapp, 1);
        expect(
          find.text(
            'No se pudo abrir WhatsApp. Verifica que esté disponible en tu navegador o dispositivo.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Adjunta el PDF descargado'),
          findsNothing,
        );
      },
    );
  });
}
