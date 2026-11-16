import 'dart:convert';

import 'package:accesorios_ayala/models/cliente.dart';
import 'package:accesorios_ayala/models/producto.dart';
import 'package:accesorios_ayala/services/pdf_service_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cliente = Cliente(
    id: 'cli-1',
    nombre: 'María López',
    telefono: '9999-8888',
    direccion: 'Colonia Centro, Casa 12',
    departamento: 'Francisco Morazán',
  );

  final seleccionados = <Map<String, dynamic>>[
    {
      'producto': Producto(
        id: 'prod-1',
        nombre: 'Aretes Dorados',
        descripcion: 'Baño de oro',
        precio: 100.0,
      ),
      'cantidad': 2,
    },
  ];

  group('PdfWebService.generarReciboPro', () {
    test(
      'genera un PDF válido usando los importes históricos cuando se pasan overrides',
      () async {
        final bytesConOverrides = await PdfWebService.generarReciboPro(
          cliente: cliente,
          seleccionados: seleccionados,
          impuestoPorcentaje: 15.0,
          envio: 150.0,
          descuentoMayoristaActivo: true,
          descuentoPorcentaje: 10.0,
          facturaNumero: 'FAC-0003',
          fechaEmision: DateTime(2026, 3, 15, 10, 30),
          subtotalOverride: 350.0,
          descuentoMontoOverride: 35.0,
          impuestoOverride: 47.25,
          totalOverride: 512.25,
        );

        expect(bytesConOverrides, isNotEmpty);
        expect(ascii.decode(bytesConOverrides.take(5).toList()), '%PDF-');
      },
    );

    test(
      'conserva la generación manual sin overrides produciendo un PDF válido',
      () async {
        final bytesManual = await PdfWebService.generarReciboPro(
          cliente: cliente,
          seleccionados: seleccionados,
          impuestoPorcentaje: 0.0,
          envio: 120.0,
          facturaNumero: 'MAN-0001',
          fechaEmision: DateTime(2026, 11, 15, 9, 0),
        );

        expect(bytesManual, isNotEmpty);
        expect(ascii.decode(bytesManual.take(5).toList()), '%PDF-');
      },
    );
  });
}
