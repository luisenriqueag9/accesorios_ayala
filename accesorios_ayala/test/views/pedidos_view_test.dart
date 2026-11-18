import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/controllers/pedido_controller.dart';
import 'package:accesorios_ayala/models/pedido.dart';
import 'package:accesorios_ayala/models/venta.dart';
import 'package:accesorios_ayala/services/reporte_pedidos_pdf_service.dart';
import 'package:accesorios_ayala/views/pedidos_view.dart';
import 'package:accesorios_ayala/views/vista_previa_recibo_view.dart';

void main() {
  Pedido crearPedido({
    EstadoElaboracionPedido estadoItem1 = EstadoElaboracionPedido.terminado,
    EstadoElaboracionPedido estadoItem2 = EstadoElaboracionPedido.terminado,
    bool facturado = false,
    String? ventaId,
    String? facturaNumero,
  }) {
    return Pedido(
      id: 'ped-ui-1',
      numeroPedido: 'PED-0021',
      clienteId: 'cli-1',
      clienteNombre: 'Ana López',
      items: [
        PedidoItem(
          itemId: 'item-1',
          productoId: 'prod-1',
          nombre: 'Pulsera Dorada',
          cantidad: 1,
          precioUnitario: 200.0,
          estadoElaboracion: estadoItem1,
        ),
        PedidoItem(
          itemId: 'item-2',
          productoId: 'prod-2',
          nombre: 'Collar Perla',
          cantidad: 1,
          precioUnitario: 350.0,
          estadoElaboracion: estadoItem2,
        ),
      ],
      facturado: facturado,
      ventaId: ventaId,
      facturaNumero: facturaNumero,
    );
  }

  Future<void> abrirDetallePedido(WidgetTester tester, Pedido pedido) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PedidosView(pedidos: [pedido]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedidos').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(pedido.numeroPedido).first);
    await tester.pumpAndSettle();
  }

  ButtonStyleButton obtenerBotonFacturar(WidgetTester tester) {
    return tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Facturar pedido'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
  }

  group('PedidosView - Opción Facturar pedido en detalle', () {
    testWidgets(
      'habilita Facturar pedido cuando todos los accesorios están terminados y no está facturado',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());

        expect(find.text('Facturar pedido'), findsOneWidget);
        expect(obtenerBotonFacturar(tester).enabled, isTrue);
        expect(
          find.textContaining('Pedido listo para facturar'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'mantiene Facturar pedido deshabilitado cuando hay accesorios en proceso o recibidos',
      (tester) async {
        await abrirDetallePedido(
          tester,
          crearPedido(estadoItem2: EstadoElaboracionPedido.enProceso),
        );

        expect(find.text('Facturar pedido'), findsOneWidget);
        expect(obtenerBotonFacturar(tester).enabled, isFalse);
      },
    );

    testWidgets(
      'deshabilita Facturar pedido cuando existen cambios provisionales sin guardar',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());
        expect(obtenerBotonFacturar(tester).enabled, isTrue);

        await tester.tap(find.text('En proceso').first);
        await tester.pumpAndSettle();

        expect(obtenerBotonFacturar(tester).enabled, isFalse);
      },
    );

    testWidgets(
      'muestra condición de facturado y deshabilita Facturar pedido si ya fue facturado o tiene ventaId',
      (tester) async {
        await abrirDetallePedido(
          tester,
          crearPedido(
            facturado: true,
            ventaId: 'venta-99',
            facturaNumero: 'FAC-0099',
          ),
        );

        expect(find.textContaining('Pedido facturado'), findsWidgets);
        expect(obtenerBotonFacturar(tester).enabled, isFalse);
      },
    );
  });

  group('PedidosView - Edición de fecha prevista de entrega', () {
    IconButton obtenerBotonEditarFecha(WidgetTester tester) {
      return tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Editar fecha de entrega'),
          matching: find.byType(IconButton),
        ),
      );
    }

    testWidgets(
      'habilita edición de fecha en pedido no facturado y la deshabilita con cambios provisionales',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());

        expect(obtenerBotonEditarFecha(tester).onPressed, isNotNull);

        await tester.tap(find.text('En proceso').first);
        await tester.pumpAndSettle();

        expect(obtenerBotonEditarFecha(tester).onPressed, isNull);
      },
    );

    testWidgets(
      'deshabilita edición de fecha cuando el pedido ya fue facturado',
      (tester) async {
        await abrirDetallePedido(
          tester,
          crearPedido(
            facturado: true,
            ventaId: 'venta-99',
            facturaNumero: 'FAC-0099',
          ),
        );

        expect(obtenerBotonEditarFecha(tester).onPressed, isNull);
      },
    );

    testWidgets(
      'muestra diálogo de confirmación con la nueva fecha antes de guardar',
      (tester) async {
        final pedidoConFecha = Pedido(
          id: 'ped-ui-fecha',
          numeroPedido: 'PED-0022',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          fechaPrevistaEntrega: DateTime.utc(2025, 5, 15, 18),
          items: [
            PedidoItem(
              itemId: 'item-1',
              productoId: 'prod-1',
              nombre: 'Pulsera Dorada',
              cantidad: 1,
              precioUnitario: 200.0,
              estadoElaboracion: EstadoElaboracionPedido.terminado,
            ),
          ],
        );

        await abrirDetallePedido(tester, pedidoConFecha);

        await tester.tap(find.byTooltip('Editar fecha de entrega'));
        await tester.pumpAndSettle();

        // Seleccionar el día 10 del mismo mes (fecha histórica permitida)
        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(
          find.text('Confirmar nueva fecha de entrega'),
          findsOneWidget,
        );
        expect(find.text('Fecha actual: 15/05/2025'), findsOneWidget);
        expect(find.text('Nueva fecha: 10/05/2025'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      },
    );
  });

  group('PedidosView - Quitar accesorio del pedido', () {
    List<IconButton> obtenerBotonesQuitar(WidgetTester tester) {
      return tester
          .widgetList<IconButton>(
            find.ancestor(
              of: find.byTooltip('Quitar accesorio'),
              matching: find.byType(IconButton),
            ),
          )
          .toList();
    }

    testWidgets(
      'habilita Quitar accesorio con múltiples ítems y lo bloquea con cambios provisionales',
      (tester) async {
        await abrirDetallePedido(tester, crearPedido());

        final botones = obtenerBotonesQuitar(tester);
        expect(botones, hasLength(2));
        expect(botones.every((b) => b.onPressed != null), isTrue);

        await tester.tap(find.text('En proceso').first);
        await tester.pumpAndSettle();

        final botonesBloqueados = obtenerBotonesQuitar(tester);
        expect(botonesBloqueados.every((b) => b.onPressed == null), isTrue);
      },
    );

    testWidgets(
      'deshabilita Quitar accesorio cuando solo queda un accesorio o el pedido está facturado',
      (tester) async {
        final pedidoUnItem = Pedido(
          id: 'ped-uno',
          numeroPedido: 'PED-0030',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          items: [
            PedidoItem(
              itemId: 'item-1',
              productoId: 'prod-1',
              nombre: 'Pulsera Única',
              cantidad: 1,
              precioUnitario: 200.0,
            ),
          ],
        );

        await abrirDetallePedido(tester, pedidoUnItem);
        final botonesUnItem = obtenerBotonesQuitar(tester);
        expect(botonesUnItem, hasLength(1));
        expect(botonesUnItem.single.onPressed, isNull);

        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();

        await abrirDetallePedido(
          tester,
          crearPedido(
            facturado: true,
            ventaId: 'venta-99',
            facturaNumero: 'FAC-0099',
          ),
        );
        final botonesFacturado = obtenerBotonesQuitar(tester);
        expect(botonesFacturado.every((b) => b.onPressed == null), isTrue);
      },
    );

    testWidgets(
      'muestra confirmación con nombre, personalización y aviso de recálculo antes de eliminar',
      (tester) async {
        final pedidoPersonalizado = Pedido(
          id: 'ped-pers',
          numeroPedido: 'PED-0031',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          items: [
            PedidoItem(
              itemId: 'item-1',
              productoId: 'prod-1',
              nombre: 'Pulsera Dorada',
              cantidad: 1,
              precioUnitario: 200.0,
              notaPersonalizacion: 'Iniciales A.L.',
            ),
            PedidoItem(
              itemId: 'item-2',
              productoId: 'prod-1',
              nombre: 'Pulsera Dorada',
              cantidad: 2,
              precioUnitario: 200.0,
              notaPersonalizacion: 'Iniciales M.P.',
            ),
          ],
        );

        await abrirDetallePedido(tester, pedidoPersonalizado);

        await tester.tap(find.byTooltip('Quitar accesorio').last);
        await tester.pumpAndSettle();

        final dialogoConfirmacion = find.byType(AlertDialog);
        expect(dialogoConfirmacion, findsOneWidget);
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Pulsera Dorada'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Personalización: Iniciales M.P.'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Cantidad: 2'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.textContaining(
              'se actualizarán los importes del pedido',
            ),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: dialogoConfirmacion,
            matching: find.text('Cancelar'),
          ),
        );
        await tester.pumpAndSettle();
      },
    );
  });

  group('PedidosView - Pestaña Facturas (historial de solo lectura)', () {
    Venta crearFactura({
      required String id,
      required String clienteNombre,
      required DateTime fecha,
      required double total,
    }) {
      return Venta(
        id: id,
        clienteId: 'cli-1',
        clienteNombre: clienteNombre,
        fecha: fecha,
        subtotal: total,
        impuesto: 0.0,
        total: total,
      );
    }

    Future<void> montarVistaFacturas(
      WidgetTester tester, {
      required Size tamano,
      List<Pedido>? pedidos,
      List<Venta>? facturas,
      Future<List<Venta>> Function()? onCargarFacturas,
      Future<Pedido?> Function(String facturaId)? onBuscarPedidoPorFactura,
    }) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PedidosView(
                pedidos: pedidos ?? const [],
                facturas: facturas,
                onCargarFacturas: onCargarFacturas,
                onBuscarPedidoPorFactura: onBuscarPedidoPorFactura,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'realiza carga diferida únicamente al abrir la pestaña Facturas y muestra estado de carga',
      (tester) async {
        var llamadas = 0;
        final completer = Completer<List<Venta>>();

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          onCargarFacturas: () {
            llamadas++;
            return completer.future;
          },
        );

        expect(llamadas, 0);

        await tester.tap(find.text('Facturas'));
        await tester.pump();

        expect(llamadas, 1);
        expect(find.text('Cargando facturas...'), findsOneWidget);

        completer.complete([
          crearFactura(
            id: 'FAC-0001',
            clienteNombre: 'Ana López',
            fecha: DateTime(2026, 11, 15, 10, 0),
            total: 620.0,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('Ana López'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra tabla en escritorio con pedido relacionado y guión cuando no está en memoria',
      (tester) async {
        final pedidosEnMemoria = [
          crearPedido(
            facturado: true,
            ventaId: 'FAC-0002',
            facturaNumero: 'FAC-0002',
          ),
        ];
        final listaFacturas = [
          crearFactura(
            id: 'FAC-0002',
            clienteNombre: 'Ana López',
            fecha: DateTime(2026, 11, 15, 14, 0),
            total: 920.50,
          ),
          crearFactura(
            id: 'FAC-0001',
            clienteNombre: 'Carlos Pérez',
            fecha: DateTime(2026, 11, 14, 9, 0),
            total: 450.0,
          ),
        ];

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          pedidos: pedidosEnMemoria,
          facturas: listaFacturas,
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        expect(find.text('N.º Factura'), findsOneWidget);
        expect(find.text('Cliente'), findsOneWidget);
        expect(find.text('Pedido'), findsOneWidget);
        expect(find.text('Fecha'), findsOneWidget);
        expect(find.text('Total'), findsOneWidget);

        expect(find.text('FAC-0002'), findsOneWidget);
        expect(find.text('Ana López'), findsOneWidget);
        expect(find.text('PED-0021'), findsOneWidget);
        expect(find.text('L. 920.50'), findsOneWidget);

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('Carlos Pérez'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
        expect(find.text('L. 450.00'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra tarjetas en móvil sin desbordamiento horizontal',
      (tester) async {
        final pedidosEnMemoria = [
          crearPedido(
            facturado: true,
            ventaId: 'FAC-0010',
            facturaNumero: 'FAC-0010',
          ),
        ];

        await montarVistaFacturas(
          tester,
          tamano: const Size(390, 844),
          pedidos: pedidosEnMemoria,
          facturas: [
            crearFactura(
              id: 'FAC-0010',
              clienteNombre: 'María Fernanda Rodríguez de la Cruz',
              fecha: DateTime(2026, 11, 15, 11, 0),
              total: 1250.0,
            ),
          ],
        );

        final pestanaFacturas = find.text('Facturas');
        await tester.ensureVisible(pestanaFacturas);
        await tester.pumpAndSettle();

        await tester.tap(pestanaFacturas);
        await tester.pumpAndSettle();

        expect(find.text('N.º Factura'), findsNothing);
        expect(find.text('FAC-0010'), findsOneWidget);
        expect(find.text('L. 1250.00'), findsOneWidget);
        expect(
          find.text('María Fernanda Rodríguez de la Cruz'),
          findsOneWidget,
        );
        expect(find.text('Pedido: PED-0021'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('muestra estado vacío cuando no hay facturas emitidas', (
      tester,
    ) async {
      await montarVistaFacturas(
        tester,
        tamano: const Size(1400, 900),
        onCargarFacturas: () async => [],
      );

      await tester.tap(find.text('Facturas'));
      await tester.pumpAndSettle();

      expect(find.text('No hay facturas emitidas'), findsOneWidget);
    });

    testWidgets(
      'muestra error distinguido, permite reintentar y no bloquea otras pestañas',
      (tester) async {
        var intento = 0;

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          onCargarFacturas: () async {
            intento++;
            if (intento == 1) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              );
            }
            return [
              crearFactura(
                id: 'FAC-0005',
                clienteNombre: 'Elena Ruiz',
                fecha: DateTime(2026, 11, 15, 12, 0),
                total: 700.0,
              ),
            ];
          },
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        expect(find.text('No se pudieron cargar las facturas'), findsOneWidget);
        expect(find.textContaining('permisos suficientes'), findsOneWidget);

        // Las demás pestañas siguen operativas pese al error en Facturas.
        await tester.tap(find.text('Resumen'));
        await tester.pumpAndSettle();
        expect(find.text('Resumen de pedidos'), findsOneWidget);

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.text('FAC-0005'), findsOneWidget);
        expect(find.text('Elena Ruiz'), findsOneWidget);
      },
    );

    testWidgets(
      'actualiza sin duplicados y conserva facturas previas si falla una actualización',
      (tester) async {
        var intento = 0;
        final completerActualizacion = Completer<List<Venta>>();

        await montarVistaFacturas(
          tester,
          tamano: const Size(1400, 900),
          onCargarFacturas: () {
            intento++;
            if (intento == 1) {
              return Future.value([
                crearFactura(
                  id: 'FAC-0001',
                  clienteNombre: 'Ana López',
                  fecha: DateTime(2026, 11, 14, 10, 0),
                  total: 500.0,
                ),
              ]);
            }
            if (intento == 2) {
              return completerActualizacion.future;
            }
            return Future.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              ),
            );
          },
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();
        expect(find.text('FAC-0001'), findsOneWidget);

        // Primera actualización: muestra indicador discreto y reemplaza sin duplicar.
        await tester.tap(find.text('Actualizar'));
        await tester.pump();
        expect(find.text('Actualizando facturas...'), findsOneWidget);
        expect(find.text('FAC-0001'), findsOneWidget);

        completerActualizacion.complete([
          crearFactura(
            id: 'FAC-0002',
            clienteNombre: 'Luis Gómez',
            fecha: DateTime(2026, 11, 15, 10, 0),
            total: 800.0,
          ),
          crearFactura(
            id: 'FAC-0001',
            clienteNombre: 'Ana López',
            fecha: DateTime(2026, 11, 14, 10, 0),
            total: 500.0,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('FAC-0002'), findsOneWidget);

        // Segunda actualización falla: conserva los datos y muestra aviso no bloqueante.
        await tester.tap(find.text('Actualizar'));
        await tester.pumpAndSettle();

        expect(find.text('FAC-0001'), findsOneWidget);
        expect(find.text('FAC-0002'), findsOneWidget);
        expect(find.textContaining('Error de conexión'), findsOneWidget);
        expect(
          find.textContaining('Se muestran las facturas disponibles en memoria'),
          findsOneWidget,
        );
      },
    );

    testWidgets('muestra el botón Ver factura con icono de ojo en escritorio', (
      tester,
    ) async {
      await montarVistaFacturas(
        tester,
        tamano: const Size(1280, 900),
        facturas: [
          crearFactura(
            id: 'FAC-0020',
            clienteNombre: 'Ana López',
            fecha: DateTime(2026, 11, 14, 10, 0),
            total: 500.0,
          ),
        ],
      );

      await tester.tap(find.text('Facturas'));
      await tester.pumpAndSettle();

      expect(find.text('Ver factura'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('muestra el botón Ver factura con icono de ojo en móvil', (
      tester,
    ) async {
      await montarVistaFacturas(
        tester,
        tamano: const Size(390, 844),
        facturas: [
          crearFactura(
            id: 'FAC-0021',
            clienteNombre: 'Sofía Martínez',
            fecha: DateTime(2026, 11, 14, 10, 0),
            total: 650.0,
          ),
        ],
      );

      final pestanaFacturas = find.text('Facturas');
      await tester.ensureVisible(pestanaFacturas);
      await tester.pumpAndSettle();
      await tester.tap(pestanaFacturas);
      await tester.pumpAndSettle();

      expect(find.text('Ver factura'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets(
      'navega a VistaPreviaReciboView en modo solo lectura usando el pedido en memoria',
      (tester) async {
        var respaldoInvocado = false;
        final pedidoRelacionado = crearPedido(
          facturado: true,
          facturaNumero: 'FAC-0022',
          ventaId: 'FAC-0022',
        );
        final factura = Venta(
          id: 'FAC-0022',
          clienteId: 'cli-1',
          clienteNombre: 'Ana López',
          fecha: DateTime(2026, 11, 14, 10, 0),
          subtotal: 320.0,
          impuesto: 48.0,
          total: 488.0,
          envio: 120.0,
        );

        await montarVistaFacturas(
          tester,
          tamano: const Size(1440, 900),
          pedidos: [pedidoRelacionado],
          facturas: [factura],
          onBuscarPedidoPorFactura: (_) async {
            respaldoInvocado = true;
            return null;
          },
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ver factura'));
        await tester.pumpAndSettle();

        expect(respaldoInvocado, isFalse);
        expect(find.byType(VistaPreviaReciboView), findsOneWidget);
        expect(find.text('Solo lectura'), findsOneWidget);
        expect(find.text('Factura #FAC-0022'), findsOneWidget);
        expect(find.text('Fecha de emisión: 14/11/2026'), findsOneWidget);
        expect(find.text('Pulsera Dorada'), findsOneWidget);
        expect(find.text('Collar Perla'), findsOneWidget);
        expect(find.text('Lps 488.00'), findsOneWidget);

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
      'usa la consulta de respaldo cuando el pedido no está en memoria y navega en solo lectura',
      (tester) async {
        final consultas = <String>[];
        final pedidoRespaldo = crearPedido(
          facturado: true,
          facturaNumero: 'FAC-0023',
          ventaId: 'FAC-0023',
        );
        final factura = crearFactura(
          id: 'FAC-0023',
          clienteNombre: 'Ana López',
          fecha: DateTime(2026, 11, 15, 11, 0),
          total: 440.0,
        );

        await montarVistaFacturas(
          tester,
          tamano: const Size(1440, 900),
          pedidos: const [],
          facturas: [factura],
          onBuscarPedidoPorFactura: (facturaId) async {
            consultas.add(facturaId);
            return pedidoRespaldo;
          },
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ver factura'));
        await tester.pumpAndSettle();

        expect(consultas, ['FAC-0023']);
        expect(find.byType(VistaPreviaReciboView), findsOneWidget);
        expect(find.text('Solo lectura'), findsOneWidget);
        expect(find.text('Factura #FAC-0023'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra un mensaje claro y no navega si no se encuentra el pedido relacionado',
      (tester) async {
        await montarVistaFacturas(
          tester,
          tamano: const Size(1440, 900),
          pedidos: const [],
          facturas: [
            crearFactura(
              id: 'FAC-0024',
              clienteNombre: 'Cliente Sin Pedido',
              fecha: DateTime(2026, 11, 15, 12, 0),
              total: 300.0,
            ),
          ],
          onBuscarPedidoPorFactura: (_) async => null,
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ver factura'));
        await tester.pumpAndSettle();

        expect(find.byType(VistaPreviaReciboView), findsNothing);
        expect(
          find.text('No se encontró el pedido relacionado a la factura FAC-0024.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'evita aperturas duplicadas mientras se consulta el pedido de respaldo',
      (tester) async {
        final completer = Completer<Pedido?>();
        var llamadas = 0;

        await montarVistaFacturas(
          tester,
          tamano: const Size(1440, 900),
          pedidos: const [],
          facturas: [
            crearFactura(
              id: 'FAC-0025',
              clienteNombre: 'Ana López',
              fecha: DateTime(2026, 11, 15, 13, 0),
              total: 520.0,
            ),
          ],
          onBuscarPedidoPorFactura: (_) {
            llamadas++;
            return completer.future;
          },
        );

        await tester.tap(find.text('Facturas'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ver factura'));
        await tester.pump();

        expect(find.text('Abriendo...'), findsOneWidget);

        await tester.tap(find.text('Abriendo...'), warnIfMissed: false);
        await tester.pump();

        expect(llamadas, 1);

        completer.complete(
          crearPedido(
            facturado: true,
            facturaNumero: 'FAC-0025',
            ventaId: 'FAC-0025',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VistaPreviaReciboView), findsOneWidget);
        expect(find.text('Solo lectura'), findsOneWidget);
      },
    );
  });

  group('PedidosView - Pestaña Alertas de entregas', () {
    // Mediodía de Honduras (12:00 UTC-6 = 18:00 UTC) del 16 de noviembre de 2026.
    final referencia = DateTime.utc(2026, 11, 16, 18);

    Pedido crearPedidoAlerta({
      required String id,
      required String numero,
      required String cliente,
      DateTime? fechaEntrega,
      EstadoEnvioPedido estadoEnvio = EstadoEnvioPedido.pendiente,
      EstadoElaboracionPedido estadoItem = EstadoElaboracionPedido.enProceso,
    }) {
      return Pedido(
        id: id,
        numeroPedido: numero,
        clienteId: 'cli-$id',
        clienteNombre: cliente,
        estadoEnvio: estadoEnvio,
        fechaPrevistaEntrega: fechaEntrega,
        items: [
          PedidoItem(
            itemId: 'item-$id',
            productoId: 'prod-1',
            nombre: 'Pulsera Dorada',
            cantidad: 1,
            precioUnitario: 200,
            estadoElaboracion: estadoItem,
          ),
        ],
      );
    }

    Future<void> abrirAlertas(
      WidgetTester tester,
      List<Pedido> listaPedidos, {
      Size tamano = const Size(1280, 900),
    }) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PedidosView(
                pedidos: listaPedidos,
                fechaReferenciaAlertas: referencia,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableSubmenu = find
          .ancestor(
            of: find.text('Resumen'),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Alertas'),
        200,
        scrollable: scrollableSubmenu,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alertas'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'clasifica entregas urgentes (<=7 días) y programadas (>7 días), excluye entregados, incluye enviados y ordena ascendentemente',
      (tester) async {
        final pedidosPrueba = [
          // +15 días (programada)
          crearPedidoAlerta(
            id: 'p15',
            numero: 'PED-0015',
            cliente: 'Elena Programada 15',
            fechaEntrega: DateTime(2026, 12, 1),
          ),
          // +7 días (urgente - límite exacto)
          crearPedidoAlerta(
            id: 'p7',
            numero: 'PED-0007',
            cliente: 'Sofía Próxima 7',
            fechaEntrega: DateTime(2026, 11, 23),
          ),
          // -2 días (atrasado, enviado pero aún no entregado)
          crearPedidoAlerta(
            id: 'p1',
            numero: 'PED-0001',
            cliente: 'Carlos Enviado Atrasado',
            fechaEntrega: DateTime(2026, 11, 14),
            estadoEnvio: EstadoEnvioPedido.enviado,
            estadoItem: EstadoElaboracionPedido.terminado,
          ),
          // +1 día (mañana - urgente)
          crearPedidoAlerta(
            id: 'p3',
            numero: 'PED-0003',
            cliente: 'Lucía Mañana',
            fechaEntrega: DateTime(2026, 11, 17),
          ),
          // Entregado (debe excluirse aunque esté en fecha)
          crearPedidoAlerta(
            id: 'p_ent',
            numero: 'PED-0099',
            cliente: 'Cliente Entregado',
            fechaEntrega: DateTime(2026, 11, 16),
            estadoEnvio: EstadoEnvioPedido.entregado,
          ),
          // +8 días (programada)
          crearPedidoAlerta(
            id: 'p8',
            numero: 'PED-0008',
            cliente: 'Diego Programado 8',
            fechaEntrega: DateTime(2026, 11, 24),
          ),
          // Hoy (urgente)
          crearPedidoAlerta(
            id: 'p2',
            numero: 'PED-0002',
            cliente: 'María Hoy',
            fechaEntrega: DateTime(2026, 11, 16),
          ),
          // Sin fecha prevista (debe contarse en aviso discreto)
          crearPedidoAlerta(
            id: 'p_sin',
            numero: 'PED-0101',
            cliente: 'Cliente Sin Fecha',
            fechaEntrega: null,
          ),
        ];

        await abrirAlertas(tester, pedidosPrueba);

        // Indicadores de urgentes: 1 atrasado, 2 hoy/mañana, 1 próximo (2 a 7 días).
        expect(find.text('Atrasados'), findsOneWidget);
        expect(find.text('Hoy / Mañana'), findsOneWidget);
        expect(find.text('Próximos (2 a 7 días)'), findsOneWidget);

        // Encabezados de ambas secciones.
        expect(find.text('Entregas urgentes'), findsOneWidget);
        expect(
          find.text('Entregas programadas (más de 7 días)'),
          findsOneWidget,
        );

        // Inclusiones y exclusiones.
        expect(find.text('PED-0001'), findsOneWidget);
        expect(find.text('PED-0002'), findsOneWidget);
        expect(find.text('PED-0003'), findsOneWidget);
        expect(find.text('PED-0007'), findsOneWidget);
        expect(find.text('PED-0008'), findsOneWidget);
        expect(find.text('PED-0015'), findsOneWidget);
        expect(find.text('PED-0099'), findsNothing);
        expect(find.text('PED-0101'), findsNothing);

        // Textos de días restantes/atraso, etiqueta Programado y aviso sin fecha.
        expect(find.text('Atrasado 2 días'), findsOneWidget);
        expect(find.text('Vence hoy'), findsOneWidget);
        expect(find.text('Falta 1 día'), findsOneWidget);
        expect(find.text('Faltan 7 días'), findsOneWidget);
        expect(find.text('Faltan 8 días'), findsOneWidget);
        expect(find.text('Faltan 15 días'), findsOneWidget);
        expect(find.text('Programado'), findsNWidgets(2));
        expect(
          find.text('1 pedido no entregado no tiene fecha prevista de entrega.'),
          findsOneWidget,
        );

        // Orden ascendente en urgentes: PED-0001 -> PED-0002 -> PED-0003 -> PED-0007.
        final y1 = tester.getTopLeft(find.text('PED-0001')).dy;
        final y2 = tester.getTopLeft(find.text('PED-0002')).dy;
        final y3 = tester.getTopLeft(find.text('PED-0003')).dy;
        final y7 = tester.getTopLeft(find.text('PED-0007')).dy;
        expect(y1 < y2, isTrue);
        expect(y2 < y3, isTrue);
        expect(y3 < y7, isTrue);

        // Orden ascendente en programadas (después de urgentes): PED-0008 -> PED-0015.
        final y8 = tester.getTopLeft(find.text('PED-0008')).dy;
        final y15 = tester.getTopLeft(find.text('PED-0015')).dy;
        expect(y7 < y8, isTrue);
        expect(y8 < y15, isTrue);
      },
    );

    testWidgets(
      'muestra entregas programadas normalmente cuando no hay entregas urgentes',
      (tester) async {
        await abrirAlertas(tester, [
          crearPedidoAlerta(
            id: 'p15',
            numero: 'PED-0015',
            cliente: 'Elena 15',
            fechaEntrega: DateTime(2026, 12, 1),
          ),
          crearPedidoAlerta(
            id: 'p8',
            numero: 'PED-0008',
            cliente: 'Diego 8',
            fechaEntrega: DateTime(2026, 11, 24),
          ),
        ]);

        expect(find.text('Entregas urgentes'), findsNothing);
        expect(find.text('Sin alertas de entrega'), findsNothing);
        expect(
          find.text('Entregas programadas (más de 7 días)'),
          findsOneWidget,
        );
        expect(find.text('PED-0008'), findsOneWidget);
        expect(find.text('PED-0015'), findsOneWidget);
        expect(find.text('Programado'), findsNWidgets(2));

        final y8 = tester.getTopLeft(find.text('PED-0008')).dy;
        final y15 = tester.getTopLeft(find.text('PED-0015')).dy;
        expect(y8 < y15, isTrue);
      },
    );

    testWidgets(
      'presentación en móvil (390x720) sin desbordamientos con urgentes, programadas y estado vacío',
      (tester) async {
        await abrirAlertas(
          tester,
          [
            crearPedidoAlerta(
              id: 'p_movil_urg',
              numero: 'PED-0010',
              cliente: 'Valeria Móvil',
              fechaEntrega: DateTime(2026, 11, 16),
            ),
            crearPedidoAlerta(
              id: 'p_movil_prog',
              numero: 'PED-0012',
              cliente: 'Mateo Programado',
              fechaEntrega: DateTime(2026, 11, 30),
            ),
          ],
          tamano: const Size(390, 720),
        );

        expect(find.text('Entregas urgentes'), findsOneWidget);
        expect(
          find.text('Entregas programadas (más de 7 días)'),
          findsOneWidget,
        );
        expect(find.text('PED-0010'), findsOneWidget);
        expect(find.text('PED-0012'), findsOneWidget);
        expect(find.text('Vence hoy'), findsOneWidget);
        expect(find.text('Faltan 14 días'), findsOneWidget);

        await abrirAlertas(
          tester,
          const [],
          tamano: const Size(390, 720),
        );

        expect(find.text('Sin alertas de entrega'), findsOneWidget);
      },
    );
  });

  group('PedidosView - Pestaña Reportes (Etapa 1)', () {
    // Miércoles 18 de noviembre de 2026 a las 12:00 Honduras (18:00 UTC).
    final referencia = DateTime.utc(2026, 11, 18, 18);

    Pedido crearPedidoReporte({
      required String id,
      required String numero,
      required double precio,
      DateTime? createdAt,
      DateTime? fechaPrevistaEntrega,
      EstadoEnvioPedido estadoEnvio = EstadoEnvioPedido.pendiente,
    }) {
      return Pedido(
        id: id,
        numeroPedido: numero,
        clienteId: 'cli-$id',
        clienteNombre: 'Cliente $id',
        estadoEnvio: estadoEnvio,
        createdAt: createdAt,
        fechaPrevistaEntrega: fechaPrevistaEntrega,
        items: [
          PedidoItem(
            itemId: 'item-$id',
            productoId: 'prod-1',
            nombre: 'Pulsera',
            cantidad: 1,
            precioUnitario: precio,
          ),
        ],
      );
    }

    Future<void> abrirReportes(
      WidgetTester tester,
      List<Pedido> listaPedidos, {
      DateTime? fechaRef,
      Size tamano = const Size(1280, 900),
    }) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PedidosView(
                pedidos: listaPedidos,
                fechaReferenciaReportes: fechaRef ?? referencia,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableSubmenu = find
          .ancestor(
            of: find.text('Resumen'),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Reportes'),
        200,
        scrollable: scrollableSubmenu,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reportes'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'calcula conteos y sumas monetarias exactas para hoy, semana (lunes-domingo) y mes, incluyendo entregados y excluyendo sin createdAt',
      (tester) async {
        final lista = [
          // Hoy (miércoles 18/11 00:00 HN = 06:00Z), entregado, fecha entrega en otro mes para confirmar que usa createdAt.
          crearPedidoReporte(
            id: 'r1',
            numero: 'PED-0001',
            precio: 150.25,
            createdAt: DateTime.utc(2026, 11, 18, 6, 0),
            fechaPrevistaEntrega: DateTime(2026, 12, 5),
            estadoEnvio: EstadoEnvioPedido.entregado,
          ),
          // Ayer martes (17/11 23:59 HN = 18/11 05:59Z) -> no hoy, sí semana y mes.
          crearPedidoReporte(
            id: 'r2',
            numero: 'PED-0002',
            precio: 100.25,
            createdAt: DateTime.utc(2026, 11, 18, 5, 59),
          ),
          // Lunes de esta semana (16/11 06:00 HN = 12:00Z) -> sí semana y mes.
          crearPedidoReporte(
            id: 'r3',
            numero: 'PED-0003',
            precio: 200.50,
            createdAt: DateTime.utc(2026, 11, 16, 12, 0),
          ),
          // Domingo semana anterior (15/11 23:30 HN = 16/11 05:30Z) -> no semana, sí mes.
          crearPedidoReporte(
            id: 'r4',
            numero: 'PED-0004',
            precio: 100.00,
            createdAt: DateTime.utc(2026, 11, 16, 5, 30),
          ),
          // Mes anterior (31/10 HN) -> excluido de los tres.
          crearPedidoReporte(
            id: 'r5',
            numero: 'PED-0005',
            precio: 500.00,
            createdAt: DateTime.utc(2026, 10, 31, 18, 0),
          ),
          // Sin fecha de creación -> excluido con aviso discreto.
          crearPedidoReporte(
            id: 'r6',
            numero: 'PED-0006',
            precio: 300.00,
            createdAt: null,
          ),
        ];

        await abrirReportes(tester, lista);

        expect(find.text('Hoy'), findsNWidgets(2));
        expect(find.text('Esta semana'), findsNWidgets(2));
        expect(find.text('Este mes'), findsNWidgets(2));
        expect(find.text('Total registrado'), findsNWidgets(3));

        // Hoy: 1 pedido, L. 150.25
        expect(find.text('1 pedido'), findsOneWidget);
        expect(find.text('L. 150.25'), findsOneWidget);

        // Semana: 3 pedidos, L. 451.00
        expect(find.text('3 pedidos'), findsOneWidget);
        expect(find.text('L. 451.00'), findsOneWidget);

        // Mes: 4 pedidos, L. 551.00
        expect(find.text('4 pedidos'), findsOneWidget);
        expect(find.text('L. 551.00'), findsOneWidget);

        expect(
          find.text(
            '1 pedido no tiene fecha de creación y fue excluido de los períodos.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'respeta el cambio de día de Honduras a las 06:00 UTC y límites de mes',
      (tester) async {
        final pedidosFrontera = [
          // 17/11 23:30 HN = 18/11 05:30Z
          crearPedidoReporte(
            id: 'f1',
            numero: 'PED-0010',
            precio: 50.00,
            createdAt: DateTime.utc(2026, 11, 18, 5, 30),
          ),
          // 18/11 00:00 HN = 18/11 06:00Z
          crearPedidoReporte(
            id: 'f2',
            numero: 'PED-0011',
            precio: 75.00,
            createdAt: DateTime.utc(2026, 11, 18, 6, 0),
          ),
          // Primer día del mes: 01/11 00:00 HN = 01/11 06:00Z
          crearPedidoReporte(
            id: 'f3',
            numero: 'PED-0012',
            precio: 25.00,
            createdAt: DateTime.utc(2026, 11, 1, 6, 0),
          ),
        ];

        // A las 06:00 UTC del 18/11 ya es 18/11 00:00 en Honduras.
        await abrirReportes(
          tester,
          pedidosFrontera,
          fechaRef: DateTime.utc(2026, 11, 18, 6, 0),
        );

        expect(find.text('1 pedido'), findsOneWidget);
        expect(find.text('L. 75.00'), findsOneWidget);
        expect(find.text('2 pedidos'), findsOneWidget);
        expect(find.text('L. 125.00'), findsOneWidget);
        expect(find.text('3 pedidos'), findsOneWidget);
        expect(find.text('L. 150.00'), findsOneWidget);
      },
    );

    testWidgets(
      'presentación en móvil (390x720) sin desbordamientos y estado vacío',
      (tester) async {
        await abrirReportes(
          tester,
          [
            crearPedidoReporte(
              id: 'm1',
              numero: 'PED-0020',
              precio: 99.95,
              createdAt: DateTime.utc(2026, 11, 18, 12, 0),
            ),
          ],
          tamano: const Size(390, 720),
        );

        expect(find.text('Hoy'), findsNWidgets(2));
        expect(find.text('Esta semana'), findsNWidgets(2));
        expect(find.text('Este mes'), findsNWidgets(2));
        expect(find.text('1 pedido'), findsNWidgets(3));
        expect(find.text('L. 99.95'), findsNWidgets(3));

        await abrirReportes(
          tester,
          const [],
          tamano: const Size(390, 720),
        );

        expect(find.text('0 pedidos'), findsNWidgets(3));
        expect(find.text('L. 0.00'), findsNWidgets(3));
        expect(find.text('Sin pedidos registrados'), findsOneWidget);
      },
    );
  });

  group('PedidosView - Acción de descarga PDF (Etapa 2B Paso 1)', () {
    // 18 de noviembre de 2026 00:30 Honduras (18/11 06:30 UTC).
    final referencia = DateTime.utc(2026, 11, 18, 6, 30);

    final pedidosPrueba = [
      Pedido(
        id: 'pdf-1',
        numeroPedido: 'PED-0001',
        clienteId: 'cli-1',
        clienteNombre: 'María José Muñoz',
        estadoEnvio: EstadoEnvioPedido.pendiente,
        createdAt: DateTime.utc(2026, 11, 18, 6, 10),
        items: [
          PedidoItem(
            itemId: 'item-1',
            productoId: 'prod-1',
            nombre: 'Pulsera',
            cantidad: 1,
            precioUnitario: 150.00,
          ),
        ],
      ),
    ];

    Future<State<PedidosView>> montarPedidosView(
      WidgetTester tester, {
      DateTime? fechaRef,
      Future<Uint8List> Function({
        required List<Pedido> pedidos,
        required PeriodoReportePedidos periodo,
        DateTime? fechaReferencia,
      })? onGenerar,
      void Function(Uint8List bytes, String nombreArchivo)? onDescargar,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PedidosView(
                pedidos: pedidosPrueba,
                fechaReferenciaReportes: fechaRef ?? referencia,
                onGenerarReportePdf: onGenerar,
                onDescargarReportePdf: onDescargar,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state<State<PedidosView>>(find.byType(PedidosView));
    }

    testWidgets(
      'genera PDF válido con nombre según período y fecha Honduras e invoca callback',
      (tester) async {
        final descargas = <({Uint8List bytes, String nombre})>[];
        final state = await montarPedidosView(
          tester,
          onDescargar: (bytes, nombre) {
            descargas.add((bytes: bytes, nombre: nombre));
          },
        );

        await PedidosView.ejecutarDescargaReportePdfParaPruebas(state);
        await tester.pump();

        expect(descargas, hasLength(1));
        expect(descargas.first.nombre, 'reporte_pedidos_hoy_20261118.pdf');
        expect(ascii.decode(descargas.first.bytes.take(5).toList()), '%PDF-');
        expect(PedidosView.generandoReportePdfParaPruebas(state), isFalse);
        expect(
          find.text('Reporte PDF descargado: reporte_pedidos_hoy_20261118.pdf'),
          findsOneWidget,
        );

        await PedidosView.ejecutarDescargaReportePdfParaPruebas(
          state,
          periodo: PeriodoReportePedidos.semana,
        );
        await tester.pump();
        expect(descargas, hasLength(2));
        expect(descargas[1].nombre, 'reporte_pedidos_semana_20261118.pdf');

        await PedidosView.ejecutarDescargaReportePdfParaPruebas(
          state,
          periodo: PeriodoReportePedidos.mes,
        );
        await tester.pump();
        expect(descargas, hasLength(3));
        expect(descargas[2].nombre, 'reporte_pedidos_mes_202611.pdf');
      },
    );

    testWidgets(
      'impide ejecuciones simultáneas mientras _generandoReportePdf está activo',
      (tester) async {
        var llamadasDescarga = 0;
        final state = await montarPedidosView(
          tester,
          onDescargar: (_, __) {
            llamadasDescarga++;
          },
        );

        final primera = PedidosView.ejecutarDescargaReportePdfParaPruebas(state);
        expect(PedidosView.generandoReportePdfParaPruebas(state), isTrue);

        final segunda = PedidosView.ejecutarDescargaReportePdfParaPruebas(state);
        await Future.wait([primera, segunda]);
        await tester.pump();

        expect(llamadasDescarga, 1);
        expect(PedidosView.generandoReportePdfParaPruebas(state), isFalse);
      },
    );

    testWidgets(
      'restablece _generandoReportePdf y muestra mensaje claro si falla la descarga',
      (tester) async {
        final state = await montarPedidosView(
          tester,
          onDescargar: (_, __) {
            throw StateError('Fallo simulado de descarga');
          },
        );

        await PedidosView.ejecutarDescargaReportePdfParaPruebas(state);
        await tester.pump();

        expect(PedidosView.generandoReportePdfParaPruebas(state), isFalse);
        expect(
          find.text('No se pudo generar el reporte PDF. Intenta nuevamente.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'no ejecuta la descarga si la vista se desmonta mientras se genera el PDF',
      (tester) async {
        final completer = Completer<Uint8List>();
        var llamadasDescarga = 0;
        final state = await montarPedidosView(
          tester,
          onGenerar: ({
            required pedidos,
            required periodo,
            fechaReferencia,
          }) => completer.future,
          onDescargar: (_, __) {
            llamadasDescarga++;
          },
        );

        final futuroDescarga =
            PedidosView.ejecutarDescargaReportePdfParaPruebas(state);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        expect(state.mounted, isFalse);

        completer.complete(Uint8List.fromList([1, 2, 3]));
        await futuroDescarga;
        await tester.pump();

        expect(llamadasDescarga, 0);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('PedidosView - Interfaz de exportación PDF en Reportes (Etapa 2B Paso 2)', () {
    final referencia = DateTime.utc(2026, 11, 18, 18);

    final pedidosPrueba = [
      Pedido(
        id: 'ui-pdf-1',
        numeroPedido: 'PED-0001',
        clienteId: 'cli-1',
        clienteNombre: 'María José Muñoz',
        estadoEnvio: EstadoEnvioPedido.pendiente,
        createdAt: DateTime.utc(2026, 11, 18, 12, 0),
        items: [
          PedidoItem(
            itemId: 'item-1',
            productoId: 'prod-1',
            nombre: 'Pulsera',
            cantidad: 1,
            precioUnitario: 200.00,
          ),
        ],
      ),
    ];

    Future<void> abrirReportesConCallbacks(
      WidgetTester tester, {
      Size tamano = const Size(1280, 900),
      Future<Uint8List> Function({
        required List<Pedido> pedidos,
        required PeriodoReportePedidos periodo,
        DateTime? fechaReferencia,
      })? onGenerar,
      void Function(Uint8List bytes, String nombreArchivo)? onDescargar,
    }) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PedidosView(
                pedidos: pedidosPrueba,
                fechaReferenciaReportes: referencia,
                onGenerarReportePdf: onGenerar,
                onDescargarReportePdf: onDescargar,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableSubmenu = find
          .ancestor(
            of: find.text('Resumen'),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Reportes'),
        200,
        scrollable: scrollableSubmenu,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reportes'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'muestra la sección Exportar reporte en PDF con Hoy seleccionado por defecto y permite cambiar período',
      (tester) async {
        final periodosGenerados = <PeriodoReportePedidos>[];
        final archivosDescargados = <String>[];

        await abrirReportesConCallbacks(
          tester,
          onGenerar: ({
            required pedidos,
            required periodo,
            fechaReferencia,
          }) async {
            periodosGenerados.add(periodo);
            return Uint8List.fromList('%PDF-1.4'.codeUnits);
          },
          onDescargar: (_, nombreArchivo) {
            archivosDescargados.add(nombreArchivo);
          },
        );

        expect(find.text('Exportar reporte en PDF'), findsOneWidget);
        expect(find.text('Descargar PDF'), findsOneWidget);

        final chipHoy = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('chip_periodo_pdf_hoy')),
        );
        final chipSemana = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('chip_periodo_pdf_semana')),
        );
        final chipMes = tester.widget<ChoiceChip>(
          find.byKey(const ValueKey('chip_periodo_pdf_mes')),
        );
        expect(chipHoy.selected, isTrue);
        expect(chipSemana.selected, isFalse);
        expect(chipMes.selected, isFalse);

        // Descarga con período inicial (Hoy)
        await tester.tap(find.byKey(const ValueKey('btn_descargar_reporte_pdf')));
        await tester.pumpAndSettle();

        // Selecciona Esta semana y descarga
        await tester.tap(find.byKey(const ValueKey('chip_periodo_pdf_semana')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('btn_descargar_reporte_pdf')));
        await tester.pumpAndSettle();

        // Selecciona Este mes y descarga
        await tester.tap(find.byKey(const ValueKey('chip_periodo_pdf_mes')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('btn_descargar_reporte_pdf')));
        await tester.pumpAndSettle();

        expect(periodosGenerados, [
          PeriodoReportePedidos.hoy,
          PeriodoReportePedidos.semana,
          PeriodoReportePedidos.mes,
        ]);
        expect(archivosDescargados, [
          'reporte_pedidos_hoy_20261118.pdf',
          'reporte_pedidos_semana_20261118.pdf',
          'reporte_pedidos_mes_202611.pdf',
        ]);
      },
    );

    testWidgets(
      'deshabilita el botón y muestra progreso mientras se genera el PDF',
      (tester) async {
        final completer = Completer<Uint8List>();
        var descargas = 0;

        await abrirReportesConCallbacks(
          tester,
          onGenerar: ({
            required pedidos,
            required periodo,
            fechaReferencia,
          }) => completer.future,
          onDescargar: (_, __) {
            descargas++;
          },
        );

        await tester.tap(find.byKey(const ValueKey('btn_descargar_reporte_pdf')));
        await tester.pump();

        expect(find.text('Generando PDF...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        final botonCargando = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('btn_descargar_reporte_pdf')),
        );
        expect(botonCargando.onPressed, isNull);

        completer.complete(Uint8List.fromList([1, 2, 3]));
        await tester.pumpAndSettle();

        expect(descargas, 1);
        expect(find.text('Descargar PDF'), findsOneWidget);
        final botonHabilitado = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey('btn_descargar_reporte_pdf')),
        );
        expect(botonHabilitado.onPressed, isNotNull);
      },
    );

    testWidgets(
      'no presenta desbordamientos en escritorio (1280x900) ni en móvil (390x720)',
      (tester) async {
        await abrirReportesConCallbacks(
          tester,
          tamano: const Size(1280, 900),
        );
        expect(find.text('Exportar reporte en PDF'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await abrirReportesConCallbacks(
          tester,
          tamano: const Size(390, 720),
        );
        expect(find.text('Exportar reporte en PDF'), findsOneWidget);
        expect(find.text('Descargar PDF'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('PedidosView - Marcar como enviado (Etapa 3 Paso 3E-C)', () {
    final updatedAtBase = DateTime.utc(2026, 11, 18, 12, 0);

    List<PedidoItem> crearItemsEnvio(
      int cantidad, {
      EstadoElaboracionPedido estado = EstadoElaboracionPedido.terminado,
    }) {
      return List<PedidoItem>.generate(
        cantidad,
        (i) => PedidoItem(
          itemId: 'item-env-${i + 1}',
          productoId: 'prod-${i + 1}',
          nombre: 'Pulsera ${i + 1}',
          cantidad: 1,
          precioUnitario: 100.0,
          estadoElaboracion: estado,
        ),
      );
    }

    Pedido crearPedidoEnvio({
      String id = 'ped-env-1',
      String numeroPedido = 'PED-0050',
      EstadoEnvioPedido estadoEnvio = EstadoEnvioPedido.pendiente,
      List<PedidoItem>? items,
      bool facturado = false,
      String? ventaId,
      String? facturaNumero,
      DateTime? updatedAt,
      bool sinUpdatedAt = false,
      DateTime? fechaEnvio,
    }) {
      return Pedido(
        id: id,
        numeroPedido: numeroPedido,
        clienteId: 'cli-env-1',
        clienteNombre: 'María José Muñoz',
        estadoEnvio: estadoEnvio,
        items: items ?? crearItemsEnvio(2),
        facturado: facturado,
        ventaId: ventaId,
        facturaNumero: facturaNumero,
        fechaEnvio: fechaEnvio,
        createdAt: DateTime.utc(2026, 11, 18, 10, 0),
        updatedAt: sinUpdatedAt ? null : (updatedAt ?? updatedAtBase),
      );
    }

    Future<void> abrirDetalleEnvio(
      WidgetTester tester,
      Pedido pedido, {
      Future<Pedido> Function({
        required String pedidoId,
        required DateTime? updatedAtEsperado,
      })? onMarcar,
    }) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PedidosView(
                pedidos: [pedido],
                onMarcarPedidoComoEnviado: onMarcar,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submenuScrollable = find
          .ancestor(
            of: find.text('Resumen'),
            matching: find.byType(Scrollable),
          )
          .first;
      final pestanaPedidos = find.descendant(
        of: submenuScrollable,
        matching: find.text('Pedidos'),
      );
      await tester.tap(pestanaPedidos);
      await tester.pumpAndSettle();

      await tester.tap(find.text(pedido.numeroPedido));
      await tester.pumpAndSettle();
    }

    OutlinedButton? obtenerBotonEnvio(WidgetTester tester) {
      final finder = find.byKey(const ValueKey('btn_marcar_pedido_enviado'));
      if (finder.evaluate().isEmpty) return null;
      return tester.widget<OutlinedButton>(finder);
    }

    testWidgets(
      'habilita el botón en pedido pendiente y facturado con producción terminada',
      (tester) async {
        await abrirDetalleEnvio(tester, crearPedidoEnvio());
        final btnPendiente = obtenerBotonEnvio(tester);
        expect(btnPendiente, isNotNull);
        expect(btnPendiente!.onPressed, isNotNull);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        await abrirDetalleEnvio(
          tester,
          crearPedidoEnvio(
            id: 'ped-env-fac',
            numeroPedido: 'PED-0051',
            facturado: true,
            ventaId: 'FAC-0010',
            facturaNumero: 'FAC-0010',
          ),
        );
        final btnFacturado = obtenerBotonEnvio(tester);
        expect(btnFacturado, isNotNull);
        expect(btnFacturado!.onPressed, isNotNull);
      },
    );

    testWidgets(
      'deshabilita el botón cuando producción está incompleta, sin artículos o sin updatedAt',
      (tester) async {
        await abrirDetalleEnvio(
          tester,
          crearPedidoEnvio(
            items: [
              PedidoItem(
                itemId: 'i1',
                productoId: 'p1',
                nombre: 'Pulsera',
                cantidad: 1,
                precioUnitario: 100,
                estadoElaboracion: EstadoElaboracionPedido.terminado,
              ),
              PedidoItem(
                itemId: 'i2',
                productoId: 'p2',
                nombre: 'Collar',
                cantidad: 1,
                precioUnitario: 100,
                estadoElaboracion: EstadoElaboracionPedido.enProceso,
              ),
            ],
          ),
        );
        expect(obtenerBotonEnvio(tester)?.onPressed, isNull);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        await abrirDetalleEnvio(
          tester,
          crearPedidoEnvio(items: const []),
        );
        expect(obtenerBotonEnvio(tester)?.onPressed, isNull);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        await abrirDetalleEnvio(
          tester,
          crearPedidoEnvio(sinUpdatedAt: true),
        );
        expect(obtenerBotonEnvio(tester)?.onPressed, isNull);
      },
    );

    testWidgets(
      'no permite repetir el envío en pedidos ya enviados ni en históricos entregados',
      (tester) async {
        await abrirDetalleEnvio(
          tester,
          crearPedidoEnvio(
            estadoEnvio: EstadoEnvioPedido.enviado,
            fechaEnvio: DateTime.utc(2026, 11, 18, 15, 0),
          ),
        );
        expect(obtenerBotonEnvio(tester), isNull);
        expect(find.text('Envío: Enviado'), findsAtLeastNWidgets(2));

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        await abrirDetalleEnvio(
          tester,
          crearPedidoEnvio(estadoEnvio: EstadoEnvioPedido.entregado),
        );
        expect(obtenerBotonEnvio(tester), isNull);
        expect(find.text('Envío: Entregado'), findsAtLeastNWidgets(2));
      },
    );

    testWidgets(
      'cancelar la confirmación no ejecuta el callback y confirmar envía pedidoId y updatedAt exactos',
      (tester) async {
        final llamadas = <({String pedidoId, DateTime? updatedAt})>[];
        final pedido = crearPedidoEnvio();

        await abrirDetalleEnvio(
          tester,
          pedido,
          onMarcar: ({
            required pedidoId,
            required updatedAtEsperado,
          }) async {
            llamadas.add((
              pedidoId: pedidoId,
              updatedAt: updatedAtEsperado,
            ));
            return pedido.copyWith(
              estadoEnvio: EstadoEnvioPedido.enviado,
              fechaEnvio: DateTime.utc(2026, 11, 18, 18, 30),
              updatedAt: DateTime.utc(2026, 11, 18, 18, 30),
            );
          },
        );

        final btnFinder = find.byKey(const ValueKey('btn_marcar_pedido_enviado'));
        await tester.ensureVisible(btnFinder);
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();

        expect(find.text('Confirmar envío del pedido'), findsOneWidget);
        expect(find.text('Transición: Pendiente → Enviado'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(llamadas, isEmpty);

        await tester.ensureVisible(btnFinder);
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar envío'));
        await tester.pumpAndSettle();

        expect(llamadas, hasLength(1));
        expect(llamadas.single.pedidoId, pedido.id);
        expect(llamadas.single.updatedAt, updatedAtBase);
        expect(
          find.text('Pedido marcado como enviado correctamente.'),
          findsOneWidget,
        );
        expect(find.text('Envío: Enviado'), findsAtLeastNWidgets(1));
        expect(find.text('Producción: Terminado'), findsAtLeastNWidgets(1));
        expect(obtenerBotonEnvio(tester), isNull);
      },
    );

    testWidgets(
      'bloquea nuevas operaciones mientras el envío está pendiente y permite 25 artículos terminados',
      (tester) async {
        final completer = Completer<Pedido>();
        final pedido25 = crearPedidoEnvio(
          id: 'ped-25',
          numeroPedido: 'PED-0075',
          items: crearItemsEnvio(25, estado: EstadoElaboracionPedido.terminado),
        );

        await abrirDetalleEnvio(
          tester,
          pedido25,
          onMarcar: ({required pedidoId, required updatedAtEsperado}) =>
              completer.future,
        );

        final btnFinder = find.byKey(const ValueKey('btn_marcar_pedido_enviado'));
        await tester.ensureVisible(btnFinder);
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirmar envío'));
        await tester.pump();

        expect(find.text('Marcando como enviado...'), findsOneWidget);
        expect(obtenerBotonEnvio(tester)?.onPressed, isNull);

        completer.complete(
          pedido25.copyWith(
            estadoEnvio: EstadoEnvioPedido.enviado,
            fechaEnvio: DateTime.utc(2026, 11, 18, 19, 0),
            updatedAt: DateTime.utc(2026, 11, 18, 19, 0),
          ),
        );
        await tester.pumpAndSettle();

        expect(obtenerBotonEnvio(tester), isNull);
        expect(find.text('Envío: Enviado'), findsAtLeastNWidgets(1));
        expect(find.text('Producción: Terminado'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'muestra error del servidor y libera el bloqueo, y muestra aviso ante conflicto de concurrencia',
      (tester) async {
        final pedido = crearPedidoEnvio();
        var modo = 'error';

        await abrirDetalleEnvio(
          tester,
          pedido,
          onMarcar: ({required pedidoId, required updatedAtEsperado}) async {
            if (modo == 'error') {
              throw const PedidoControllerException(
                tipo: TipoErrorPedido.permisosInsuficientes,
                mensaje: 'No tienes permisos administrativos.',
              );
            }
            throw const PedidoControllerException(
              tipo: TipoErrorPedido.conflictoConcurrencia,
              mensaje: 'Conflicto de concurrencia.',
            );
          },
        );

        final btnFinder = find.byKey(const ValueKey('btn_marcar_pedido_enviado'));
        await tester.ensureVisible(btnFinder);
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar envío'));
        await tester.pumpAndSettle();

        expect(find.text('No tienes permisos administrativos.'), findsOneWidget);
        expect(obtenerBotonEnvio(tester)?.onPressed, isNotNull);

        modo = 'conflicto';
        await tester.ensureVisible(btnFinder);
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar envío'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Otro administrador modificó este pedido'),
          findsOneWidget,
        );
        expect(obtenerBotonEnvio(tester)?.onPressed, isNull);
      },
    );
  });
}
