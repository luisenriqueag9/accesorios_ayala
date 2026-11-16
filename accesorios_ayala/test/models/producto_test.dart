import 'package:accesorios_ayala/models/producto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Producto.visibleCatalogo', () {
    test('un producto nuevo es visible por defecto', () {
      final producto = Producto(
        id: 'prod-1',
        nombre: 'Pulsera Dorada',
        descripcion: 'Acero inoxidable',
        precio: 250.0,
        imageUrl: 'https://ejemplo.com/pulsera.png',
      );

      expect(producto.visibleCatalogo, isTrue);
      expect(producto.id, 'prod-1');
      expect(producto.nombre, 'Pulsera Dorada');
      expect(producto.descripcion, 'Acero inoxidable');
      expect(producto.precio, 250.0);
      expect(producto.imageUrl, 'https://ejemplo.com/pulsera.png');
    });

    test('fromMap sin campo visibleCatalogo lo interpreta como true', () {
      final producto = Producto.fromMap({
        'id': 'prod-antiguo',
        'nombre': 'Collar Perla',
        'descripcion': 'Diseño clásico',
        'precio': 320,
        'imageUrl': null,
      });

      expect(producto.visibleCatalogo, isTrue);
      expect(producto.id, 'prod-antiguo');
      expect(producto.nombre, 'Collar Perla');
      expect(producto.descripcion, 'Diseño clásico');
      expect(producto.precio, 320.0);
      expect(producto.imageUrl, isNull);
    });

    test('fromMap interpreta correctamente visibleCatalogo: false', () {
      final producto = Producto.fromMap({
        'id': 'prod-oculto',
        'nombre': 'Llavero Grabado',
        'descripcion': 'Grabado láser',
        'precio': 150.0,
        'visibleCatalogo': false,
      });

      expect(producto.visibleCatalogo, isFalse);
      expect(producto.nombre, 'Llavero Grabado');
      expect(producto.precio, 150.0);
    });

    test('fromMap interpreta correctamente visibleCatalogo: true', () {
      final producto = Producto.fromMap({
        'id': 'prod-visible',
        'nombre': 'Aretes Sol',
        'descripcion': 'Baño de oro',
        'precio': 180.0,
        'visibleCatalogo': true,
      });

      expect(producto.visibleCatalogo, isTrue);
    });

    test('fromMap interpreta valores no booleanos como true', () {
      for (final valorInvalido in ['false', 0, 1, null, <String>[]]) {
        final producto = Producto.fromMap({
          'id': 'prod-invalido',
          'nombre': 'Caja Regalo',
          'descripcion': 'Edición especial',
          'precio': 400.0,
          'visibleCatalogo': valorInvalido,
        });

        expect(producto.visibleCatalogo, isTrue);
      }
    });

    test('toMap incluye visibleCatalogo y conserva los demás campos', () {
      final producto = Producto(
        id: 'prod-2',
        nombre: 'Placa Personalizada',
        descripcion: 'Acero con grabado láser',
        precio: 290.5,
        imageUrl: 'https://ejemplo.com/placa.jpg',
        visibleCatalogo: false,
      );

      final map = producto.toMap();

      expect(map, {
        'id': 'prod-2',
        'nombre': 'Placa Personalizada',
        'descripcion': 'Acero con grabado láser',
        'precio': 290.5,
        'imageUrl': 'https://ejemplo.com/placa.jpg',
        'visibleCatalogo': false,
      });
    });
  });
}
