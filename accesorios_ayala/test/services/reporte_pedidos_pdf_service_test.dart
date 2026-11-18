import 'dart:convert';

import 'package:accesorios_ayala/models/pedido.dart';
import 'package:accesorios_ayala/services/reporte_pedidos_pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Miércoles 18 de noviembre de 2026 a las 12:00 Honduras (18:00 UTC).
  final referencia = DateTime.utc(2026, 11, 18, 18);

  Pedido crearPedido({
    required String id,
    required String numero,
    required double precio,
    String? clienteNombre,
    DateTime? createdAt,
    EstadoEnvioPedido estadoEnvio = EstadoEnvioPedido.pendiente,
  }) {
    return Pedido(
      id: id,
      numeroPedido: numero,
      clienteId: 'cli-$id',
      clienteNombre: clienteNombre ?? 'Cliente $id',
      estadoEnvio: estadoEnvio,
      createdAt: createdAt,
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

  final pedidosBase = <Pedido>[
    // Hoy (miércoles 18/11 00:00 HN = 06:00Z), entregado.
    crearPedido(
      id: 'p1',
      numero: 'PED-0001',
      precio: 150.25,
      createdAt: DateTime.utc(2026, 11, 18, 6, 0),
      estadoEnvio: EstadoEnvioPedido.entregado,
    ),
    // Ayer martes (17/11 23:59 HN = 18/11 05:59Z) -> no hoy, sí semana y mes.
    crearPedido(
      id: 'p2',
      numero: 'PED-0002',
      precio: 100.25,
      createdAt: DateTime.utc(2026, 11, 18, 5, 59),
    ),
    // Lunes de la semana actual (16/11 06:00 HN = 12:00Z).
    crearPedido(
      id: 'p3',
      numero: 'PED-0003',
      precio: 200.50,
      createdAt: DateTime.utc(2026, 11, 16, 12, 0),
    ),
    // Domingo semana anterior (15/11 23:30 HN = 16/11 05:30Z) -> solo mes.
    crearPedido(
      id: 'p4',
      numero: 'PED-0004',
      precio: 100.00,
      createdAt: DateTime.utc(2026, 11, 16, 5, 30),
    ),
    // Mes anterior -> fuera de los tres períodos.
    crearPedido(
      id: 'p5',
      numero: 'PED-0005',
      precio: 500.00,
      createdAt: DateTime.utc(2026, 10, 31, 18, 0),
    ),
    // Sin fecha de creación -> excluido.
    crearPedido(
      id: 'p6',
      numero: 'PED-0006',
      precio: 300.00,
      createdAt: null,
    ),
  ];

  group('ReportePedidosPdfService - cálculos de períodos y montos', () {
    test('calcula hoy, semana (lunes-domingo) y mes con exactitud', () {
      final hoy = ReportePedidosPdfService.prepararDatos(
        pedidos: pedidosBase,
        periodo: PeriodoReportePedidos.hoy,
        fechaReferencia: referencia,
      );
      expect(hoy.cantidadPedidos, 1);
      expect(hoy.totalRegistrado, 150.25);
      expect(hoy.sinFechaCreacion, 1);
      expect(hoy.pedidos.map((p) => p.id), ['p1']);

      final semana = ReportePedidosPdfService.prepararDatos(
        pedidos: pedidosBase,
        periodo: PeriodoReportePedidos.semana,
        fechaReferencia: referencia,
      );
      expect(semana.cantidadPedidos, 3);
      expect(semana.totalRegistrado, 451.00);
      expect(semana.pedidos.map((p) => p.id), ['p3', 'p2', 'p1']);

      final mes = ReportePedidosPdfService.prepararDatos(
        pedidos: pedidosBase,
        periodo: PeriodoReportePedidos.mes,
        fechaReferencia: referencia,
      );
      expect(mes.cantidadPedidos, 4);
      expect(mes.totalRegistrado, 551.00);
      expect(mes.pedidos.map((p) => p.id), ['p4', 'p3', 'p2', 'p1']);
    });

    test('respeta límites de fecha de Honduras a las 06:00 UTC', () {
      final antesMedianocheHn = ReportePedidosPdfService.prepararDatos(
        pedidos: pedidosBase,
        periodo: PeriodoReportePedidos.hoy,
        fechaReferencia: DateTime.utc(2026, 11, 18, 5, 59),
      );
      expect(antesMedianocheHn.cantidadPedidos, 1);
      expect(antesMedianocheHn.pedidos.single.id, 'p2');
    });
  });

  group('ReportePedidosPdfService - generación de PDF', () {
    test('genera PDF válido para hoy, semana y mes cargando el logo oficial', () async {
      for (final periodo in PeriodoReportePedidos.values) {
        final bytes = await ReportePedidosPdfService.generarReporte(
          pedidos: pedidosBase,
          periodo: periodo,
          fechaReferencia: referencia,
        );

        expect(bytes, isNotEmpty);
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      }
    });

    test('maneja correctamente una lista vacía', () async {
      final bytes = await ReportePedidosPdfService.generarReporte(
        pedidos: const [],
        periodo: PeriodoReportePedidos.hoy,
        fechaReferencia: referencia,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('genera múltiples páginas cuando hay muchos pedidos', () async {
      final muchos = List<Pedido>.generate(
        50,
        (i) => crearPedido(
          id: 'm$i',
          numero: 'PED-${(i + 1).toString().padLeft(4, '0')}',
          precio: 125.10,
          createdAt: DateTime.utc(2026, 11, 18, 12, 0).add(
            Duration(minutes: i),
          ),
        ),
      );

      final datos = ReportePedidosPdfService.prepararDatos(
        pedidos: muchos,
        periodo: PeriodoReportePedidos.hoy,
        fechaReferencia: referencia,
      );
      expect(datos.cantidadPedidos, 50);
      expect(datos.totalRegistrado, 6255.00);

      final bytes = await ReportePedidosPdfService.generarReporte(
        pedidos: muchos,
        periodo: PeriodoReportePedidos.hoy,
        fechaReferencia: referencia,
      );
      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    });

    test('lanza error claro si no puede cargarse el logo oficial', () async {
      await expectLater(
        () => ReportePedidosPdfService.generarReporte(
          pedidos: pedidosBase,
          periodo: PeriodoReportePedidos.hoy,
          fechaReferencia: referencia,
          bundle: _BundleFallido(),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'genera PDF con caracteres Unicode (tildes y ñ) usando las tres fuentes locales sin internet',
      () async {
        final bundleEspia = _BundleEspia(rootBundle);
        final pedidosUnicode = [
          crearPedido(
            id: 'u1',
            numero: 'PED-0101',
            precio: 245.50,
            clienteNombre: 'María José Muñoz',
            createdAt: DateTime.utc(2026, 11, 18, 14, 0),
          ),
          crearPedido(
            id: 'u2',
            numero: 'PED-0102',
            precio: 180.00,
            clienteNombre: 'Álvaro Peña Núñez',
            createdAt: DateTime.utc(2026, 11, 18, 15, 0),
          ),
        ];

        final bytes = await ReportePedidosPdfService.generarReporte(
          pedidos: pedidosUnicode,
          periodo: PeriodoReportePedidos.hoy,
          fechaReferencia: referencia,
          bundle: bundleEspia,
        );

        expect(bytes, isNotEmpty);
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
        expect(
          bundleEspia.clavesSolicitadas,
          containsAll(<String>[
            ReportePedidosPdfService.rutaLogoOficial,
            ReportePedidosPdfService.rutaFuenteRegular,
            ReportePedidosPdfService.rutaFuenteBold,
            ReportePedidosPdfService.rutaFuenteItalic,
          ]),
        );
      },
    );

    test('formatea importes individuales con el mismo redondeo en centavos que el total', () {
      final pedidosDecimales = [
        crearPedido(
          id: 'd1',
          numero: 'PED-0201',
          precio: 10.124,
          createdAt: DateTime.utc(2026, 11, 18, 12, 0),
        ),
        crearPedido(
          id: 'd2',
          numero: 'PED-0202',
          precio: 20.125,
          createdAt: DateTime.utc(2026, 11, 18, 13, 0),
        ),
        crearPedido(
          id: 'd3',
          numero: 'PED-0203',
          precio: 35.855,
          createdAt: DateTime.utc(2026, 11, 18, 14, 0),
        ),
      ];

      final datos = ReportePedidosPdfService.prepararDatos(
        pedidos: pedidosDecimales,
        periodo: PeriodoReportePedidos.hoy,
        fechaReferencia: referencia,
      );

      final importesFilas = pedidosDecimales
          .map((p) => ReportePedidosPdfService.formatearLempiras(p.totalEstimado))
          .toList();

      expect(importesFilas, ['L. 10.12', 'L. 20.13', 'L. 35.85']);

      final sumaCentavosFilas = pedidosDecimales.fold<int>(
        0,
        (sum, p) => sum + (p.totalEstimado * 100).round(),
      );
      expect(
        ReportePedidosPdfService.formatearLempiras(datos.totalRegistrado),
        'L. ${(sumaCentavosFilas / 100.0).toStringAsFixed(2)}',
      );
      expect(
        ReportePedidosPdfService.formatearLempiras(datos.totalRegistrado),
        'L. 66.10',
      );
    });

    test('lanza error claro si falla la carga de una fuente Unicode obligatoria', () async {
      final bundleSinBold = _BundleFalloEnClave(
        delegate: rootBundle,
        claveFallida: ReportePedidosPdfService.rutaFuenteBold,
      );

      await expectLater(
        () => ReportePedidosPdfService.generarReporte(
          pedidos: pedidosBase,
          periodo: PeriodoReportePedidos.hoy,
          fechaReferencia: referencia,
          bundle: bundleSinBold,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains(ReportePedidosPdfService.rutaFuenteBold),
          ),
        ),
      );
    });
  });

  group('ReportePedidosPdfService - columnas Producción y Envío', () {
    test(
      'genera PDF con combinaciones independientes de Producción y Envío y conserva totales',
      () async {
        final pedidosCombinados = <Pedido>[
          // 1. Producción Terminado + Envío Pendiente
          Pedido(
            id: 'c1',
            numeroPedido: 'PED-0001',
            clienteId: 'cli-1',
            clienteNombre: 'María José Muñoz',
            estadoEnvio: EstadoEnvioPedido.pendiente,
            createdAt: DateTime.utc(2026, 11, 18, 12, 0),
            items: [
              PedidoItem(
                itemId: 'i1',
                productoId: 'prod-1',
                nombre: 'Pulsera',
                cantidad: 1,
                precioUnitario: 120.50,
                estadoElaboracion: EstadoElaboracionPedido.terminado,
              ),
            ],
          ),
          // 2. Producción Terminado + Envío Enviado
          Pedido(
            id: 'c2',
            numeroPedido: 'PED-0002',
            clienteId: 'cli-2',
            clienteNombre: 'Álvaro Peña Núñez',
            estadoEnvio: EstadoEnvioPedido.enviado,
            createdAt: DateTime.utc(2026, 11, 18, 13, 0),
            items: [
              PedidoItem(
                itemId: 'i2',
                productoId: 'prod-2',
                nombre: 'Collar',
                cantidad: 1,
                precioUnitario: 200.25,
                estadoElaboracion: EstadoElaboracionPedido.terminado,
              ),
            ],
          ),
          // 3. Producción En proceso + Envío Pendiente
          Pedido(
            id: 'c3',
            numeroPedido: 'PED-0003',
            clienteId: 'cli-3',
            clienteNombre: 'Sofía Hernández',
            estadoEnvio: EstadoEnvioPedido.pendiente,
            createdAt: DateTime.utc(2026, 11, 18, 14, 0),
            items: [
              PedidoItem(
                itemId: 'i3a',
                productoId: 'prod-1',
                nombre: 'Pulsera',
                cantidad: 1,
                precioUnitario: 50.00,
                estadoElaboracion: EstadoElaboracionPedido.terminado,
              ),
              PedidoItem(
                itemId: 'i3b',
                productoId: 'prod-2',
                nombre: 'Aretes',
                cantidad: 1,
                precioUnitario: 50.00,
                estadoElaboracion: EstadoElaboracionPedido.recibido,
              ),
            ],
          ),
          // 4. Producción Recibido sin ítems + Envío Pendiente
          Pedido(
            id: 'c4',
            numeroPedido: 'PED-0004',
            clienteId: 'cli-4',
            clienteNombre: 'José Ángel Güiti',
            estadoEnvio: EstadoEnvioPedido.pendiente,
            createdAt: DateTime.utc(2026, 11, 18, 15, 0),
            items: const [],
          ),
          // 5. Compatibilidad con pedido existente de Firestore sin estados explícitos
          Pedido.fromMap({
            'numeroPedido': 'PED-0005',
            'clienteId': 'cli-5',
            'clienteNombre': 'Cliente Histórico',
            'createdAt': DateTime.utc(2026, 11, 18, 16, 0).toIso8601String(),
            'items': [
              {
                'itemId': 'i5',
                'productoId': 'prod-5',
                'nombre': 'Anillo',
                'cantidad': 2,
                'precioUnitario': 40.00,
              },
            ],
          }, id: 'c5'),
        ];

        expect(
          pedidosCombinados[0].estadoProduccion.etiqueta,
          'Terminado',
        );
        expect(pedidosCombinados[0].estadoEnvio.etiqueta, 'Pendiente');

        expect(
          pedidosCombinados[1].estadoProduccion.etiqueta,
          'Terminado',
        );
        expect(pedidosCombinados[1].estadoEnvio.etiqueta, 'Enviado');

        expect(
          pedidosCombinados[2].estadoProduccion.etiqueta,
          'En proceso',
        );
        expect(pedidosCombinados[2].estadoEnvio.etiqueta, 'Pendiente');

        expect(
          pedidosCombinados[3].estadoProduccion.etiqueta,
          'Recibido',
        );
        expect(pedidosCombinados[3].estadoEnvio.etiqueta, 'Pendiente');

        expect(
          pedidosCombinados[4].estadoProduccion.etiqueta,
          'Recibido',
        );
        expect(pedidosCombinados[4].estadoEnvio.etiqueta, 'Pendiente');

        final datos = ReportePedidosPdfService.prepararDatos(
          pedidos: pedidosCombinados,
          periodo: PeriodoReportePedidos.hoy,
          fechaReferencia: referencia,
        );
        expect(datos.cantidadPedidos, 5);
        expect(datos.totalRegistrado, 500.75);

        final bytes = await ReportePedidosPdfService.generarReporte(
          pedidos: pedidosCombinados,
          periodo: PeriodoReportePedidos.hoy,
          fechaReferencia: referencia,
        );
        expect(bytes, isNotEmpty);
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      },
    );

    test(
      'genera reporte multipágina con seis columnas alternando estados de producción y envío',
      () async {
        const estadosItem = EstadoElaboracionPedido.values;
        const estadosEnvio = EstadoEnvioPedido.values;

        final muchos = List<Pedido>.generate(45, (i) {
          return Pedido(
            id: 'mp-$i',
            numeroPedido: 'PED-${(i + 1).toString().padLeft(4, '0')}',
            clienteId: 'cli-$i',
            clienteNombre: 'Cliente $i',
            estadoEnvio: estadosEnvio[i % estadosEnvio.length],
            createdAt: DateTime.utc(2026, 11, 18, 12, 0).add(
              Duration(minutes: i),
            ),
            items: [
              PedidoItem(
                itemId: 'imp-$i',
                productoId: 'prod-1',
                nombre: 'Pulsera',
                cantidad: 1,
                precioUnitario: 100.00,
                estadoElaboracion: estadosItem[i % estadosItem.length],
              ),
            ],
          );
        });

        final datos = ReportePedidosPdfService.prepararDatos(
          pedidos: muchos,
          periodo: PeriodoReportePedidos.hoy,
          fechaReferencia: referencia,
        );
        expect(datos.cantidadPedidos, 45);
        expect(datos.totalRegistrado, 4500.00);

        final bytes = await ReportePedidosPdfService.generarReporte(
          pedidos: muchos,
          periodo: PeriodoReportePedidos.hoy,
          fechaReferencia: referencia,
        );
        expect(bytes, isNotEmpty);
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      },
    );
  });
}

class _BundleFallido extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    return Future<ByteData>.error(Exception('Asset no encontrado: $key'));
  }
}

class _BundleEspia extends CachingAssetBundle {
  _BundleEspia(this._delegate);

  final AssetBundle _delegate;
  final List<String> clavesSolicitadas = <String>[];

  @override
  Future<ByteData> load(String key) {
    clavesSolicitadas.add(key);
    return _delegate.load(key);
  }
}

class _BundleFalloEnClave extends CachingAssetBundle {
  _BundleFalloEnClave({required this.delegate, required this.claveFallida});

  final AssetBundle delegate;
  final String claveFallida;

  @override
  Future<ByteData> load(String key) {
    if (key == claveFallida) {
      return Future<ByteData>.error(Exception('Fuente faltante: $key'));
    }
    return delegate.load(key);
  }
}
