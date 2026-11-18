import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/controllers/pedido_controller.dart';
import 'package:accesorios_ayala/models/pedido.dart';

Pedido _crearBorradorValido({
  String clienteId = 'cli-1',
  String clienteNombre = 'Ana López',
  List<PedidoItem>? items,
  double costoEnvio = 120.0,
  BorradorFacturaPedido? borradorFactura,
  String numeroPedido = '',
  bool facturado = false,
  String? ventaId,
  String? facturaNumero,
  DateTime? fechaFacturacion,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Pedido(
    id: '',
    numeroPedido: numeroPedido,
    clienteId: clienteId,
    clienteNombre: clienteNombre,
    clienteTelefono: '9999-0000',
    clienteDireccion: 'Col. Centro',
    clienteDepartamento: 'Cortés',
    items:
        items ??
        [
          PedidoItem(
            itemId: 'item-1',
            productoId: 'prod-1',
            nombre: 'Pulsera Dorada',
            cantidad: 2,
            precioUnitario: 250.0,
            notaPersonalizacion: 'Iniciales A.L.',
          ),
        ],
    costoEnvio: costoEnvio,
    borradorFactura: borradorFactura,
    facturado: facturado,
    ventaId: ventaId,
    facturaNumero: facturaNumero,
    fechaFacturacion: fechaFacturacion,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

void main() {
  group('Pruebas unitarias puras de PedidoController', () {
    test('formatearNumeroPedido genera el formato oficial PED-0001+', () {
      expect(PedidoController.formatearNumeroPedido(1), 'PED-0001');
      expect(PedidoController.formatearNumeroPedido(9), 'PED-0009');
      expect(PedidoController.formatearNumeroPedido(10), 'PED-0010');
      expect(PedidoController.formatearNumeroPedido(99), 'PED-0099');
      expect(PedidoController.formatearNumeroPedido(100), 'PED-0100');
      expect(PedidoController.formatearNumeroPedido(999), 'PED-0999');
      expect(PedidoController.formatearNumeroPedido(1000), 'PED-1000');
      expect(PedidoController.formatearNumeroPedido(12345), 'PED-12345');
    });

    test('formatearNumeroPedido rechaza números menores que 1', () {
      expect(
        () => PedidoController.formatearNumeroPedido(0),
        throwsArgumentError,
      );
      expect(
        () => PedidoController.formatearNumeroPedido(-5),
        throwsArgumentError,
      );
    });

    test('Rechaza pedido sin identificador o nombre de cliente', () async {
      await expectLater(
        () => PedidoController.crearPedido(
          _crearBorradorValido(clienteId: '   '),
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.datosInvalidos,
          ),
        ),
      );

      await expectLater(
        () => PedidoController.crearPedido(
          _crearBorradorValido(clienteNombre: ''),
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.datosInvalidos,
          ),
        ),
      );
    });

    test('Rechaza lista de productos vacía o ítems inválidos', () async {
      await expectLater(
        () => PedidoController.crearPedido(_crearBorradorValido(items: [])),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.datosInvalidos,
          ),
        ),
      );

      await expectLater(
        () => PedidoController.crearPedido(
          _crearBorradorValido(
            items: [
              PedidoItem(
                itemId: ' ',
                productoId: 'prod-1',
                nombre: 'Pulsera',
                cantidad: 1,
                precioUnitario: 100.0,
              ),
            ],
          ),
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.datosInvalidos,
          ),
        ),
      );

      expect(
        () => PedidoItem(
          itemId: 'item-1',
          productoId: 'prod-1',
          nombre: 'Pulsera',
          cantidad: 0,
          precioUnitario: 100.0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'Rechaza precios, envío o porcentajes inválidos o no finitos',
      () async {
        await expectLater(
          () => PedidoController.crearPedido(
            _crearBorradorValido(
              items: [
                PedidoItem(
                  itemId: 'item-1',
                  productoId: 'prod-1',
                  nombre: 'Pulsera',
                  cantidad: 1,
                  precioUnitario: double.infinity,
                ),
              ],
            ),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.crearPedido(
            _crearBorradorValido(costoEnvio: double.nan),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        expect(
          () => _crearBorradorValido(costoEnvio: -1.0),
          throwsArgumentError,
        );
      },
    );

    test(
      'Rechaza pedidos con número previo, ya facturados, con venta o con fechas',
      () async {
        await expectLater(
          () => PedidoController.crearPedido(
            _crearBorradorValido(numeroPedido: 'PED-0001'),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.crearPedido(
            _crearBorradorValido(facturado: true),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.crearPedido(
            _crearBorradorValido(ventaId: 'venta-123'),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.crearPedido(
            _crearBorradorValido(createdAt: DateTime(2026, 11, 13)),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.crearPedido(
            _crearBorradorValido(),
            pedidoId: '   ',
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );
      },
    );

    test(
      'construirPedidoDefinitivo genera keywordsBusqueda y conserva cálculos sin facturar',
      () {
        final borrador = _crearBorradorValido(
          clienteNombre: '  María José Peña  ',
          costoEnvio: 150.0,
          borradorFactura: BorradorFacturaPedido(
            impuestoPorcentaje: 15.0,
            descuentoMayoristaActivo: true,
            descuentoPorcentaje: 10.0,
            costoEnvio: 150.0,
          ),
        );

        final definitivo = PedidoController.construirPedidoDefinitivo(
          borrador: borrador,
          id: 'doc-abc-123',
          numeroPedido: 'PED-0001',
        );

        expect(definitivo.id, 'doc-abc-123');
        expect(definitivo.numeroPedido, 'PED-0001');
        expect(definitivo.facturado, isFalse);
        expect(definitivo.ventaId, isNull);
        expect(definitivo.facturaNumero, isNull);
        expect(definitivo.subtotalProductos, 500.0);
        expect(definitivo.totalEstimado, 667.5);
        expect(
          definitivo.keywordsBusqueda,
          containsAll([
            'ped-0001',
            'maria',
            'jose',
            'pena',
            'pulsera',
            'dorada',
          ]),
        );
      },
    );

    test(
      'normalizarFechaPrevistaEntrega normaliza fechas históricas y actuales a 18:00:00Z',
      () {
        final historica = PedidoController.normalizarFechaPrevistaEntrega(
          DateTime(2022, 5, 14, 23, 45),
        );
        expect(historica, DateTime.utc(2022, 5, 14, 18));

        final futura = PedidoController.normalizarFechaPrevistaEntrega(
          DateTime(2027, 11, 3, 1, 10),
        );
        expect(futura, DateTime.utc(2027, 11, 3, 18));
      },
    );

    test(
      'normalizarFechaPrevistaEntrega rechaza fechas fuera de rango válido',
      () {
        expect(
          () => PedidoController.normalizarFechaPrevistaEntrega(
            DateTime(1995, 1, 1),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );
      },
    );

    test(
      'actualizarFechaPrevistaEntrega rechaza pedidoId vacío o fecha nula sin tocar Firestore',
      () async {
        await expectLater(
          () => PedidoController.actualizarFechaPrevistaEntrega(
            pedidoId: '   ',
            nuevaFechaPrevistaEntrega: DateTime(2026, 6, 10),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.actualizarFechaPrevistaEntrega(
            pedidoId: 'ped-1',
            nuevaFechaPrevistaEntrega: null,
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );
      },
    );

    test(
      'eliminarAccesorioPedido rechaza pedidoId vacío, itemId vacío o updatedAt nulo',
      () async {
        await expectLater(
          () => PedidoController.eliminarAccesorioPedido(
            pedidoId: '  ',
            itemId: 'item-1',
            updatedAtEsperado: DateTime.utc(2026, 11, 14),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.eliminarAccesorioPedido(
            pedidoId: 'ped-1',
            itemId: '  ',
            updatedAtEsperado: DateTime.utc(2026, 11, 14),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.eliminarAccesorioPedido(
            pedidoId: 'ped-1',
            itemId: 'item-1',
            updatedAtEsperado: null,
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );
      },
    );

    test(
      'filtrarItemsOriginalesSinAccesorio conserva claves, valores y tipos originales de los accesorios restantes',
      () {
        final itemRestante = <String, dynamic>{
          'itemId': 'item-1',
          'productoId': 'prod-1',
          'nombre': 'Pulsera Dorada',
          'cantidad': 1,
          'precioUnitario': 220, // int original (toMap lo convertiría a double)
          'imageUrl': null,
          'notaPersonalizacion': 'negra',
          'estadoElaboracion': 'terminado',
          'campoLegacy': 42,
        };
        final itemEliminado = <String, dynamic>{
          'itemId': 'item-2',
          'productoId': 'prod-1',
          'nombre': 'Pulsera Dorada',
          'cantidad': 1,
          'precioUnitario': 220,
          'imageUrl': null,
          'notaPersonalizacion': 'gris',
          'estadoElaboracion': 'recibido',
        };

        final resultado = PedidoController.filtrarItemsOriginalesSinAccesorio(
          rawItems: [itemRestante, itemEliminado],
          itemId: 'item-2',
        );

        expect(resultado, hasLength(1));
        expect(identical(resultado.first, itemRestante), isTrue);
        expect(resultado.first['precioUnitario'], isA<int>());
        expect(resultado.first['precioUnitario'], 220);
        expect(resultado.first['campoLegacy'], 42);
        expect(resultado.first.containsKey('imageUrl'), isTrue);
        expect(resultado.first['imageUrl'], isNull);
        expect(resultado.first['notaPersonalizacion'], 'negra');
      },
    );

    test(
      'filtrarItemsOriginalesSinAccesorio exige coincidencia única y al menos un accesorio restante',
      () {
        final item1 = <String, dynamic>{'itemId': 'item-1'};
        final item2 = <String, dynamic>{'itemId': 'item-2'};

        expect(
          () => PedidoController.filtrarItemsOriginalesSinAccesorio(
            rawItems: [item1, item2],
            itemId: 'item-inexistente',
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        expect(
          () => PedidoController.filtrarItemsOriginalesSinAccesorio(
            rawItems: [item1, item1],
            itemId: 'item-1',
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        expect(
          () => PedidoController.filtrarItemsOriginalesSinAccesorio(
            rawItems: [item1],
            itemId: 'item-1',
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );
      },
    );

    test('formatearNumeroFactura genera el formato oficial FAC-0001+', () {
      expect(PedidoController.formatearNumeroFactura(1), 'FAC-0001');
      expect(PedidoController.formatearNumeroFactura(9), 'FAC-0009');
      expect(PedidoController.formatearNumeroFactura(10), 'FAC-0010');
      expect(PedidoController.formatearNumeroFactura(999), 'FAC-0999');
      expect(PedidoController.formatearNumeroFactura(1000), 'FAC-1000');
      expect(
        () => PedidoController.formatearNumeroFactura(0),
        throwsArgumentError,
      );
    });

    test(
      'construirVentaParaPedido reutiliza BorradorFacturaPedido y genera mapa compatible con Venta',
      () {
        final pedido = _crearBorradorValido(
          costoEnvio: 120.0,
          borradorFactura: BorradorFacturaPedido(
            impuestoPorcentaje: 15.0,
            descuentoMayoristaActivo: true,
            descuentoPorcentaje: 20.0,
            costoEnvio: 120.0,
          ),
        );
        // subtotal = 2 * 250 = 500; desc = 100; base = 400; imp = 60; total = 580
        final fecha = DateTime.utc(2026, 11, 14, 18, 0);
        final venta = PedidoController.construirVentaParaPedido(
          pedido: pedido,
          facturaNumero: 'FAC-0001',
          fechaEmision: fecha,
        );

        expect(venta.id, 'FAC-0001');
        expect(venta.clienteId, 'cli-1');
        expect(venta.clienteNombre, 'Ana López');
        expect(venta.subtotal, 500.0);
        expect(venta.descuentoMayoristaActivo, isTrue);
        expect(venta.descuentoPorcentaje, 20.0);
        expect(venta.descuentoMonto, 100.0);
        expect(venta.impuesto, 60.0);
        expect(venta.envio, 120.0);
        expect(venta.total, 580.0);
        expect(venta.toMap()['id'], 'FAC-0001');
      },
    );

    test(
      'facturarPedido rechaza pedidoId vacío o updatedAtEsperado nulo',
      () async {
        await expectLater(
          () => PedidoController.facturarPedido(
            pedidoId: '  ',
            updatedAtEsperado: DateTime.utc(2026, 11, 14),
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );

        await expectLater(
          () => PedidoController.facturarPedido(
            pedidoId: 'ped-1',
            updatedAtEsperado: null,
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );
      },
    );

    test(
      'facturarPedido invoca la Cloud Function facturarPedido con pedidoId y updatedAtEsperadoMs y recarga el pedido sin escrituras directas',
      () async {
        final updatedAtLocal = DateTime(2026, 11, 14, 12, 0, 0);
        final esperadoMs = updatedAtLocal.toUtc().millisecondsSinceEpoch;
        final pedidoFacturadoMap = {
          ..._crearBorradorValido(
            numeroPedido: 'PED-0001',
            facturado: true,
            ventaId: 'FAC-0001',
            facturaNumero: 'FAC-0001',
          ).toMap(),
          'id': 'ped-1',
          'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 14, 20, 0)),
        };

        final fakeFunctions = _FakeFirebaseFunctions(
          onCall: (name, args) async {
            return {'ok': true, 'facturaNumero': 'FAC-0001'};
          },
        );
        final fakeFirestore = _FakeFirestore(
          documentoPedido: pedidoFacturadoMap,
        );

        final resultado = await PedidoController.facturarPedido(
          pedidoId: ' ped-1 ',
          updatedAtEsperado: updatedAtLocal,
          firestore: fakeFirestore,
          functions: fakeFunctions,
        );

        expect(fakeFunctions.ultimaFuncion, 'facturarPedido');
        expect(fakeFunctions.ultimoPayload, {
          'pedidoId': 'ped-1',
          'updatedAtEsperadoMs': esperadoMs,
        });
        expect(fakeFunctions.ultimoPayload!.keys, hasLength(2));
        expect(fakeFirestore.coleccionesConsultadas, ['pedidos']);
        expect(fakeFirestore.huboEscriturasOTransacciones, isFalse);
        expect(resultado.id, 'ped-1');
        expect(resultado.facturado, isTrue);
        expect(resultado.ventaId, 'FAC-0001');
        expect(resultado.facturaNumero, 'FAC-0001');
      },
    );

    test(
      'facturarPedido traduce FirebaseFunctionsException a PedidoControllerException',
      () async {
        final casos =
            <({String code, String message, TipoErrorPedido esperado})>[
              (
                code: 'unauthenticated',
                message: 'Se requiere autenticación.',
                esperado: TipoErrorPedido.permisosInsuficientes,
              ),
              (
                code: 'permission-denied',
                message: 'No tienes permisos administrativos.',
                esperado: TipoErrorPedido.permisosInsuficientes,
              ),
              (
                code: 'not-found',
                message: 'El pedido no existe.',
                esperado: TipoErrorPedido.pedidoNoEncontrado,
              ),
              (
                code: 'failed-precondition',
                message:
                    'Este pedido fue modificado por otro administrador. Recárgalo antes de facturar.',
                esperado: TipoErrorPedido.conflictoConcurrencia,
              ),
              (
                code: 'failed-precondition',
                message: 'Todos los accesorios deben estar terminados.',
                esperado: TipoErrorPedido.datosInvalidos,
              ),
              (
                code: 'unavailable',
                message: 'Servicio no disponible.',
                esperado: TipoErrorPedido.errorConexion,
              ),
            ];

        for (final caso in casos) {
          final fakeFunctions = _FakeFirebaseFunctions(
            onCall: (_, _) async {
              throw FirebaseFunctionsException(
                code: caso.code,
                message: caso.message,
              );
            },
          );
          final fakeFirestore = _FakeFirestore(documentoPedido: const {});

          await expectLater(
            () => PedidoController.facturarPedido(
              pedidoId: 'ped-1',
              updatedAtEsperado: DateTime.utc(2026, 11, 14),
              firestore: fakeFirestore,
              functions: fakeFunctions,
            ),
            throwsA(
              isA<PedidoControllerException>()
                  .having((e) => e.tipo, 'tipo', caso.esperado)
                  .having((e) => e.codigoFirebase, 'codigoFirebase', caso.code),
            ),
          );
        }
      },
    );

    test(
      'facturarPedido informa actualizacionConfirmadaSinRecarga si falla la recarga posterior',
      () async {
        final fakeFunctions = _FakeFirebaseFunctions(
          onCall: (_, _) async => {'ok': true, 'facturaNumero': 'FAC-0001'},
        );
        final fakeFirestore = _FakeFirestore(
          errorEnGet: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Sin conexión',
          ),
        );

        await expectLater(
          () => PedidoController.facturarPedido(
            pedidoId: 'ped-1',
            updatedAtEsperado: DateTime.utc(2026, 11, 14),
            firestore: fakeFirestore,
            functions: fakeFunctions,
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.actualizacionConfirmadaSinRecarga,
            ),
          ),
        );
      },
    );
  });

  group('PedidoController.marcarPedidoComoEnviado', () {
    test('rechaza pedidoId vacío o updatedAtEsperado nulo sin invocar Cloud Function', () async {
      var invocado = false;
      final fakeFunctions = _FakeFirebaseFunctions(
        onCall: (_, _) async {
          invocado = true;
          return {'ok': true};
        },
      );
      final fakeFirestore = _FakeFirestore(documentoPedido: const {});

      await expectLater(
        () => PedidoController.marcarPedidoComoEnviado(
          pedidoId: '   ',
          updatedAtEsperado: DateTime.utc(2026, 11, 18),
          firestore: fakeFirestore,
          functions: fakeFunctions,
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.datosInvalidos,
          ),
        ),
      );

      await expectLater(
        () => PedidoController.marcarPedidoComoEnviado(
          pedidoId: 'ped-1',
          updatedAtEsperado: null,
          firestore: fakeFirestore,
          functions: fakeFunctions,
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.datosInvalidos,
          ),
        ),
      );

      expect(invocado, isFalse);
      expect(fakeFirestore.huboEscriturasOTransacciones, isFalse);
    });

    test(
      'invoca marcarPedidoComoEnviado con pedidoId y updatedAtEsperadoMs, recarga desde Firestore y no escribe en cliente',
      () async {
        final updatedAtLocal = DateTime(2026, 11, 18, 10, 15);
        final esperadoMs = updatedAtLocal.toUtc().millisecondsSinceEpoch;
        final fechaEnvio = DateTime.utc(2026, 11, 18, 18, 30);
        final pedidoEnviadoMap = {
          ..._crearBorradorValido(
            numeroPedido: 'PED-0001',
            facturado: true,
            ventaId: 'FAC-0001',
            facturaNumero: 'FAC-0001',
          ).toMap(),
          'id': 'ped-1',
          'estadoEnvio': 'enviado',
          'fechaEnvio': Timestamp.fromDate(fechaEnvio),
          'updatedAt': Timestamp.fromDate(fechaEnvio),
        };

        final fakeFunctions = _FakeFirebaseFunctions(
          onCall: (name, args) async {
            return {
              'ok': true,
              'pedidoId': 'ped-1',
              'estadoEnvio': 'enviado',
            };
          },
        );
        final fakeFirestore = _FakeFirestore(
          documentoPedido: pedidoEnviadoMap,
        );

        final resultado = await PedidoController.marcarPedidoComoEnviado(
          pedidoId: ' ped-1 ',
          updatedAtEsperado: updatedAtLocal,
          firestore: fakeFirestore,
          functions: fakeFunctions,
        );

        expect(fakeFunctions.ultimaFuncion, 'marcarPedidoComoEnviado');
        expect(fakeFunctions.ultimoPayload, {
          'pedidoId': 'ped-1',
          'updatedAtEsperadoMs': esperadoMs,
        });
        expect(fakeFunctions.ultimoPayload!.keys, hasLength(2));
        expect(fakeFirestore.coleccionesConsultadas, ['pedidos']);
        expect(fakeFirestore.huboEscriturasOTransacciones, isFalse);
        expect(resultado.id, 'ped-1');
        expect(resultado.estadoEnvio, EstadoEnvioPedido.enviado);
        expect(resultado.fechaEnvio?.toUtc(), fechaEnvio);
        expect(resultado.facturado, isTrue);
      },
    );

    test(
      'traduce errores de autenticación, permisos, concurrencia y red desde FirebaseFunctionsException',
      () async {
        final casos =
            <({String code, String message, TipoErrorPedido esperado})>[
              (
                code: 'unauthenticated',
                message: 'Se requiere autenticación.',
                esperado: TipoErrorPedido.permisosInsuficientes,
              ),
              (
                code: 'permission-denied',
                message: 'No tienes permisos administrativos.',
                esperado: TipoErrorPedido.permisosInsuficientes,
              ),
              (
                code: 'not-found',
                message: 'El pedido no existe.',
                esperado: TipoErrorPedido.pedidoNoEncontrado,
              ),
              (
                code: 'failed-precondition',
                message:
                    'Este pedido fue modificado por otro administrador. Recárgalo antes de marcarlo como enviado.',
                esperado: TipoErrorPedido.conflictoConcurrencia,
              ),
              (
                code: 'failed-precondition',
                message: 'Todos los artículos del pedido deben estar terminados.',
                esperado: TipoErrorPedido.datosInvalidos,
              ),
              (
                code: 'unavailable',
                message: 'Sin conexión.',
                esperado: TipoErrorPedido.errorConexion,
              ),
            ];

        for (final caso in casos) {
          final fakeFunctions = _FakeFirebaseFunctions(
            onCall: (_, _) async {
              throw FirebaseFunctionsException(
                code: caso.code,
                message: caso.message,
              );
            },
          );
          final fakeFirestore = _FakeFirestore(documentoPedido: const {});

          await expectLater(
            () => PedidoController.marcarPedidoComoEnviado(
              pedidoId: 'ped-1',
              updatedAtEsperado: DateTime.utc(2026, 11, 18),
              firestore: fakeFirestore,
              functions: fakeFunctions,
            ),
            throwsA(
              isA<PedidoControllerException>()
                  .having((e) => e.tipo, 'tipo', caso.esperado)
                  .having((e) => e.codigoFirebase, 'codigoFirebase', caso.code),
            ),
          );
        }
      },
    );

    test(
      'informa actualizacionConfirmadaSinRecarga si falla la recarga posterior tras marcar como enviado',
      () async {
        final fakeFunctions = _FakeFirebaseFunctions(
          onCall: (_, _) async => {
            'ok': true,
            'pedidoId': 'ped-1',
            'estadoEnvio': 'enviado',
          },
        );
        final fakeFirestore = _FakeFirestore(
          errorEnGet: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Sin conexión',
          ),
        );

        await expectLater(
          () => PedidoController.marcarPedidoComoEnviado(
            pedidoId: 'ped-1',
            updatedAtEsperado: DateTime.utc(2026, 11, 18),
            firestore: fakeFirestore,
            functions: fakeFunctions,
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.actualizacionConfirmadaSinRecarga,
            ),
          ),
        );
      },
    );
  });

  group('PedidoController.cargarPedidoPorFactura', () {
    test('encuentra el pedido por facturaNumero usando limit(1) sin escribir', () async {
      final db = _FakeFirestore(
        documentosPedidos: {
          'ped-1': {
            'numeroPedido': 'PED-0010',
            'clienteId': 'cli-1',
            'clienteNombre': 'Ana López',
            'clienteTelefono': '9999-0000',
            'clienteDireccion': 'Col. Centro',
            'clienteDepartamento': 'Cortés',
            'items': [
              {
                'itemId': 'item-1',
                'productoId': 'prod-1',
                'nombre': 'Pulsera Dorada',
                'cantidad': 2,
                'precioUnitario': 250.0,
              },
            ],
            'costoEnvio': 120.0,
            'facturado': true,
            'facturaNumero': 'FAC-0010',
            'ventaId': 'FAC-0010',
          },
        },
      );

      final pedido = await PedidoController.cargarPedidoPorFactura(
        'FAC-0010',
        firestore: db,
      );

      expect(pedido, isNotNull);
      expect(pedido!.id, 'ped-1');
      expect(pedido.numeroPedido, 'PED-0010');
      expect(pedido.items, hasLength(1));
      expect(db.consultasRegistradas, ['facturaNumero=FAC-0010|limit=1']);
      expect(db.huboEscriturasOTransacciones, isFalse);
    });

    test('encuentra el pedido por ventaId cuando no coincide facturaNumero', () async {
      final db = _FakeFirestore(
        documentosPedidos: {
          'ped-2': {
            'numeroPedido': 'PED-0011',
            'clienteId': 'cli-2',
            'clienteNombre': 'Carlos Ruiz',
            'items': const [],
            'facturado': true,
            'facturaNumero': '',
            'ventaId': 'FAC-0011',
          },
        },
      );

      final pedido = await PedidoController.cargarPedidoPorFactura(
        'FAC-0011',
        firestore: db,
      );

      expect(pedido, isNotNull);
      expect(pedido!.id, 'ped-2');
      expect(pedido.numeroPedido, 'PED-0011');
      expect(db.consultasRegistradas, [
        'facturaNumero=FAC-0011|limit=1',
        'ventaId=FAC-0011|limit=1',
      ]);
      expect(db.huboEscriturasOTransacciones, isFalse);
    });

    test('retorna null cuando no existe pedido relacionado', () async {
      final db = _FakeFirestore(documentosPedidos: {});

      final pedido = await PedidoController.cargarPedidoPorFactura(
        'FAC-9999',
        firestore: db,
      );

      expect(pedido, isNull);
      expect(db.consultasRegistradas, [
        'facturaNumero=FAC-9999|limit=1',
        'ventaId=FAC-9999|limit=1',
      ]);
      expect(db.huboEscriturasOTransacciones, isFalse);
    });

    test('lanza datosInvalidos si facturaId está vacío', () async {
      final db = _FakeFirestore(documentosPedidos: {});

      for (final idInvalido in ['', '   ']) {
        await expectLater(
          () => PedidoController.cargarPedidoPorFactura(
            idInvalido,
            firestore: db,
          ),
          throwsA(
            isA<PedidoControllerException>().having(
              (e) => e.tipo,
              'tipo',
              TipoErrorPedido.datosInvalidos,
            ),
          ),
        );
      }

      expect(db.coleccionesConsultadas, isEmpty);
    });

    test('convierte FirebaseException de permisos y conexión al consultar', () async {
      final dbPermisos = _FakeFirestore(
        errorEnGet: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      await expectLater(
        () => PedidoController.cargarPedidoPorFactura(
          'FAC-0012',
          firestore: dbPermisos,
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.permisosInsuficientes,
          ),
        ),
      );

      final dbConexion = _FakeFirestore(
        errorEnGet: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );

      await expectLater(
        () => PedidoController.cargarPedidoPorFactura(
          'FAC-0012',
          firestore: dbConexion,
        ),
        throwsA(
          isA<PedidoControllerException>().having(
            (e) => e.tipo,
            'tipo',
            TipoErrorPedido.errorConexion,
          ),
        ),
      );
    });
  });
}

class _FakeFirebaseFunctions extends Fake implements FirebaseFunctions {
  _FakeFirebaseFunctions({required this.onCall});

  final Future<dynamic> Function(String name, Map<String, dynamic> args) onCall;
  String? ultimaFuncion;
  Map<String, dynamic>? ultimoPayload;

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) {
    ultimaFuncion = name;
    return _FakeHttpsCallable(
      onInvoke: (args) async {
        ultimoPayload = Map<String, dynamic>.from(args);
        return onCall(name, ultimoPayload!);
      },
    );
  }
}

class _FakeHttpsCallable extends Fake implements HttpsCallable {
  _FakeHttpsCallable({required this.onInvoke});

  final Future<dynamic> Function(Map<String, dynamic> args) onInvoke;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = await onInvoke(
      Map<String, dynamic>.from(parameters as Map<String, dynamic>),
    );
    return _FakeHttpsCallableResult<T>(data as T);
  }
}

class _FakeHttpsCallableResult<T> extends Fake
    implements HttpsCallableResult<T> {
  _FakeHttpsCallableResult(this._data);

  final T _data;

  @override
  T get data => _data;
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore({
    this.documentoPedido,
    this.documentosPedidos = const {},
    this.errorEnGet,
  });

  final Map<String, dynamic>? documentoPedido;
  final Map<String, Map<String, dynamic>> documentosPedidos;
  final Object? errorEnGet;
  final List<String> coleccionesConsultadas = [];
  final List<String> consultasRegistradas = [];
  bool huboEscriturasOTransacciones = false;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    coleccionesConsultadas.add(collectionPath);
    if (collectionPath != PedidoController.collection) {
      huboEscriturasOTransacciones = true;
      throw StateError('Acceso inesperado a colección: $collectionPath');
    }
    return _FakeCollectionReference(this);
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    huboEscriturasOTransacciones = true;
    throw StateError('facturarPedido no debe abrir transacciones en cliente');
  }
}

// ignore: subtype_of_sealed_class
class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this._db);

  final _FakeFirestore _db;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeDocumentReference(_db, path ?? '');
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return _FakeQuery(
      _db,
      campoFiltro: field.toString(),
      valorIgual: isEqualTo,
    );
  }
}

// ignore: subtype_of_sealed_class
class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery(
    this._db, {
    required this.campoFiltro,
    required this.valorIgual,
    this.limite,
  });

  final _FakeFirestore _db;
  final String campoFiltro;
  final Object? valorIgual;
  final int? limite;

  @override
  Query<Map<String, dynamic>> limit(int limit) {
    return _FakeQuery(
      _db,
      campoFiltro: campoFiltro,
      valorIgual: valorIgual,
      limite: limit,
    );
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    _db.consultasRegistradas.add(
      '$campoFiltro=$valorIgual${limite != null ? '|limit=$limite' : ''}',
    );
    if (_db.errorEnGet != null) {
      throw _db.errorEnGet!;
    }

    final coincidencias = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final entry in _db.documentosPedidos.entries) {
      if (entry.value[campoFiltro] == valorIgual) {
        coincidencias.add(_FakeQueryDocumentSnapshot(entry.key, entry.value));
        if (limite != null && coincidencias.length >= limite!) {
          break;
        }
      }
    }

    return _FakeQuerySnapshot(coincidencias);
  }
}

// ignore: subtype_of_sealed_class
class _FakeQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _FakeQuerySnapshot(this._docs);

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;
}

// ignore: subtype_of_sealed_class
class _FakeQueryDocumentSnapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _FakeQueryDocumentSnapshot(this._id, this._data);

  final String _id;
  final Map<String, dynamic> _data;

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;
}

// ignore: subtype_of_sealed_class
class _FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocumentReference(this._db, this._id);

  final _FakeFirestore _db;
  final String _id;

  @override
  String get id => _id;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    if (_db.errorEnGet != null) {
      throw _db.errorEnGet!;
    }
    return _FakeDocumentSnapshot(_id, _db.documentoPedido);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    _db.huboEscriturasOTransacciones = true;
    throw StateError('No debe escribir directamente en Firestore');
  }

  @override
  Future<void> update(Map<Object, Object?> data) {
    _db.huboEscriturasOTransacciones = true;
    throw StateError('No debe actualizar directamente en Firestore');
  }
}

// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot(this._id, this._data);

  final String _id;
  final Map<String, dynamic>? _data;

  @override
  String get id => _id;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}
