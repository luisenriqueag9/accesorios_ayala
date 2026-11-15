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
  });
}
