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
        'categoriaIds': <String>[],
      });
    });
  });

  group('Producto.categoriaIds', () {
    Map<String, dynamic> base([Map<String, dynamic> extra = const {}]) => {
      'id': 'prod-cat',
      'nombre': 'Pulsera Graduación',
      'descripcion': 'Acero grabado',
      'precio': 275.5,
      'imageUrl': 'https://ejemplo.com/grad.jpg',
      'visibleCatalogo': false,
      ...extra,
    };

    test('un producto nuevo no tiene categorías', () {
      final producto = Producto(
        id: 'p',
        nombre: 'n',
        descripcion: 'd',
        precio: 1,
      );
      expect(producto.categoriaIds, isEmpty);
      expect(producto.toMap()['categoriaIds'], <String>[]);
    });

    test('producto antiguo sin campo categoriaIds carga con lista vacía', () {
      final producto = Producto.fromMap(base());
      expect(producto.categoriaIds, isEmpty);
      expect(producto.nombre, 'Pulsera Graduación');
      expect(producto.precio, 275.5);
      expect(producto.visibleCatalogo, isFalse);
    });

    test('conserva varios IDs válidos en orden', () {
      final producto = Producto.fromMap(
        base({
          'categoriaIds': ['idPulseras', 'idGraduacion', 'idRegalos'],
        }),
      );
      expect(producto.categoriaIds, ['idPulseras', 'idGraduacion', 'idRegalos']);
    });

    test('ignora solo los elementos inválidos y conserva los válidos', () {
      final producto = Producto.fromMap(
        base({
          'categoriaIds': [1, 'idA', null, true, 'idB', 2.5, <String>[], {}],
        }),
      );
      expect(producto.categoriaIds, ['idA', 'idB']);
    });

    test('elimina IDs vacíos, recorta espacios y quita duplicados', () {
      final producto = Producto.fromMap(
        base({
          'categoriaIds': ['', '   ', ' idA ', 'idB', 'idA', '\tidB\n', 'idC'],
        }),
      );
      expect(producto.categoriaIds, ['idA', 'idB', 'idC']);
    });

    test('null o tipo incorrecto produce lista vacía', () {
      for (final valor in [null, 'idA', 5, true, {'a': 'b'}]) {
        final producto = Producto.fromMap(base({'categoriaIds': valor}));
        expect(producto.categoriaIds, isEmpty, reason: 'valor: $valor');
      }
    });

    test('toMap y fromMap son coherentes y conservan todos los campos', () {
      final original = Producto(
        id: 'prod-rt',
        nombre: 'Collar',
        descripcion: 'Plata',
        precio: 410.0,
        imageUrl: 'https://ejemplo.com/collar.jpg',
        visibleCatalogo: false,
        categoriaIds: ['idCollares', 'idMama'],
      );

      final map = original.toMap();
      expect(map, {
        'id': 'prod-rt',
        'nombre': 'Collar',
        'descripcion': 'Plata',
        'precio': 410.0,
        'imageUrl': 'https://ejemplo.com/collar.jpg',
        'visibleCatalogo': false,
        'categoriaIds': ['idCollares', 'idMama'],
      });

      final copia = Producto.fromMap(map);
      expect(copia.id, original.id);
      expect(copia.nombre, original.nombre);
      expect(copia.descripcion, original.descripcion);
      expect(copia.precio, original.precio);
      expect(copia.imageUrl, original.imageUrl);
      expect(copia.visibleCatalogo, original.visibleCatalogo);
      expect(copia.categoriaIds, original.categoriaIds);
    });

    test('la lista está protegida contra modificaciones externas', () {
      final fuente = ['idA', 'idB'];
      final producto = Producto(
        id: 'p',
        nombre: 'n',
        descripcion: 'd',
        precio: 1,
        categoriaIds: fuente,
      );

      fuente.add('idC');
      fuente[0] = 'cambiado';
      expect(producto.categoriaIds, ['idA', 'idB']);

      expect(() => producto.categoriaIds.add('idX'), throwsUnsupportedError);
      expect(() => producto.categoriaIds.clear(), throwsUnsupportedError);

      final map = producto.toMap();
      (map['categoriaIds'] as List).add('idY');
      expect(producto.categoriaIds, ['idA', 'idB']);
    });
  });
}
