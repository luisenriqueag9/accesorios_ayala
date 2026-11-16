import 'package:accesorios_ayala/models/banner_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModoBannerCatalogo', () {
    test('reconoce los tres modos válidos de Firestore', () {
      expect(
        ModoBannerCatalogo.fromValor('imagen'),
        ModoBannerCatalogo.imagen,
      );
      expect(
        ModoBannerCatalogo.fromValor('CARRUSEL'),
        ModoBannerCatalogo.carrusel,
      );
      expect(
        ModoBannerCatalogo.fromValor('  video '),
        ModoBannerCatalogo.video,
      );
    });

    test('usa imagen por defecto ante valores nulos o inválidos', () {
      expect(ModoBannerCatalogo.fromValor(null), ModoBannerCatalogo.imagen);
      expect(ModoBannerCatalogo.fromValor(123), ModoBannerCatalogo.imagen);
      expect(
        ModoBannerCatalogo.fromValor('desconocido'),
        ModoBannerCatalogo.imagen,
      );
    });
  });

  group('BannerConfig - configuración inicial y modos', () {
    test('BannerConfig.inicial crea configuración desactivada sin contenido', () {
      final config = BannerConfig.inicial();

      expect(config.activo, isFalse);
      expect(config.modo, ModoBannerCatalogo.imagen);
      expect(config.imagenUrl, isNull);
      expect(config.videoUrl, isNull);
      expect(config.carrusel, isEmpty);
      expect(
        config.intervaloSegundos,
        BannerConfig.intervaloPorDefectoSegundos,
      );
      expect(config.updatedAt, isNull);
      expect(config.tieneContenidoParaModoActivo, isFalse);
      expect(config.debeMostrarse, isFalse);
    });

    test('modo imagen: serializa y evalúa disponibilidad correctamente', () {
      final fecha = DateTime.utc(2026, 11, 16, 12, 30);
      final config = BannerConfig(
        activo: true,
        modo: ModoBannerCatalogo.imagen,
        imagenUrl: '  https://cdn.ejemplo.com/banner.jpg  ',
        updatedAt: fecha,
      );

      expect(config.imagenUrl, 'https://cdn.ejemplo.com/banner.jpg');
      expect(config.tieneContenidoParaModoActivo, isTrue);
      expect(config.debeMostrarse, isTrue);

      final map = config.toMap();
      expect(map['activo'], isTrue);
      expect(map['modo'], 'imagen');
      expect(map['imagenUrl'], 'https://cdn.ejemplo.com/banner.jpg');
      expect(map['updatedAt'], isA<Timestamp>());

      final restaurada = BannerConfig.fromMap(map);
      expect(restaurada.activo, isTrue);
      expect(restaurada.modo, ModoBannerCatalogo.imagen);
      expect(restaurada.imagenUrl, 'https://cdn.ejemplo.com/banner.jpg');
      expect(restaurada.updatedAt, fecha);
    });

    test('modo carrusel: ordena por orden administrativo y omite inválidos', () {
      final config = BannerConfig(
        activo: true,
        modo: ModoBannerCatalogo.carrusel,
        carrusel: const [
          BannerCarruselItem(
            id: 'b',
            url: 'https://cdn.ejemplo.com/2.jpg',
            orden: 2,
          ),
          BannerCarruselItem(
            id: 'a',
            url: 'https://cdn.ejemplo.com/1.jpg',
            orden: 1,
          ),
          BannerCarruselItem(id: 'vacio', url: '   ', orden: 0),
          BannerCarruselItem(
            id: 'a',
            url: 'https://cdn.ejemplo.com/duplicado.jpg',
            orden: 0,
          ),
        ],
        intervaloSegundos: 6,
      );

      expect(config.carrusel.map((e) => e.id), ['a', 'b']);
      expect(config.tieneContenidoParaModoActivo, isTrue);
      expect(config.debeMostrarse, isTrue);
      expect(
        () => config.carrusel.add(
          const BannerCarruselItem(id: 'x', url: 'https://cdn.ejemplo.com/x.jpg'),
        ),
        throwsUnsupportedError,
      );

      final restaurada = BannerConfig.fromMap(config.toMap());
      expect(restaurada.modo, ModoBannerCatalogo.carrusel);
      expect(restaurada.carrusel.length, 2);
      expect(restaurada.carrusel.first.id, 'a');
      expect(restaurada.carrusel.last.id, 'b');
      expect(restaurada.intervaloSegundos, 6);
    });

    test('modo video: evalúa contenido y round-trip de serialización', () {
      final config = BannerConfig(
        activo: true,
        modo: ModoBannerCatalogo.video,
        videoUrl: 'https://cdn.ejemplo.com/promo.mp4',
      );

      expect(config.tieneContenidoParaModoActivo, isTrue);
      expect(config.debeMostrarse, isTrue);

      final restaurada = BannerConfig.fromMap(config.toMap());
      expect(restaurada.modo, ModoBannerCatalogo.video);
      expect(restaurada.videoUrl, 'https://cdn.ejemplo.com/promo.mp4');
      expect(restaurada.debeMostrarse, isTrue);
    });

    test('activo en true sin contenido del modo activo no debe mostrarse', () {
      final sinImagen = BannerConfig(
        activo: true,
        modo: ModoBannerCatalogo.imagen,
        videoUrl: 'https://cdn.ejemplo.com/promo.mp4',
      );
      expect(sinImagen.tieneContenidoParaModoActivo, isFalse);
      expect(sinImagen.debeMostrarse, isFalse);

      final sinVideo = BannerConfig(
        activo: true,
        modo: ModoBannerCatalogo.video,
        imagenUrl: 'https://cdn.ejemplo.com/banner.jpg',
      );
      expect(sinVideo.tieneContenidoParaModoActivo, isFalse);
      expect(sinVideo.debeMostrarse, isFalse);
    });
  });

  group('BannerConfig - validación ante datos inválidos o incompletos', () {
    test('fromMap con mapa vacío no lanza error y devuelve estado seguro', () {
      final config = BannerConfig.fromMap({});

      expect(config.activo, isFalse);
      expect(config.modo, ModoBannerCatalogo.imagen);
      expect(config.imagenUrl, isNull);
      expect(config.videoUrl, isNull);
      expect(config.carrusel, isEmpty);
      expect(
        config.intervaloSegundos,
        BannerConfig.intervaloPorDefectoSegundos,
      );
      expect(config.updatedAt, isNull);
    });

    test('normaliza tipos incorrectos, intervalos fuera de rango y fechas inválidas', () {
      final config = BannerConfig.fromMap({
        'activo': 'true',
        'modo': 99,
        'imagenUrl': 12345,
        'videoUrl': '   ',
        'carrusel': [
          null,
          'no-es-mapa',
          {'id': 'sin-url', 'url': ''},
          {'id': 'ok2', 'url': 'https://cdn.ejemplo.com/2.jpg', 'orden': '10'},
          {'id': 'ok1', 'url': 'https://cdn.ejemplo.com/1.jpg', 'orden': 2.0},
        ],
        'intervaloSegundos': 120,
        'updatedAt': 'fecha-invalida',
      });

      expect(config.activo, isFalse);
      expect(config.modo, ModoBannerCatalogo.imagen);
      expect(config.imagenUrl, isNull);
      expect(config.videoUrl, isNull);
      expect(config.carrusel.map((e) => e.id), ['ok1', 'ok2']);
      expect(config.carrusel.last.orden, 10);
      expect(config.intervaloSegundos, BannerConfig.intervaloMaximoSegundos);
      expect(config.updatedAt, isNull);
    });

    test('ajusta intervalos negativos, cero o menores al mínimo', () {
      expect(
        BannerConfig(intervaloSegundos: 0).intervaloSegundos,
        BannerConfig.intervaloPorDefectoSegundos,
      );
      expect(
        BannerConfig(intervaloSegundos: -4).intervaloSegundos,
        BannerConfig.intervaloPorDefectoSegundos,
      );
      expect(
        BannerConfig(intervaloSegundos: 1).intervaloSegundos,
        BannerConfig.intervaloMinimoSegundos,
      );
    });

    test('acepta updatedAt en formato ISO-8601 y milisegundos', () {
      final porIso = BannerConfig.fromMap({
        'updatedAt': '2026-11-16T10:00:00.000Z',
      });
      expect(porIso.updatedAt, DateTime.utc(2026, 11, 16, 10, 0));

      final ms = DateTime.utc(2026, 11, 16, 15, 0).millisecondsSinceEpoch;
      final porMs = BannerConfig.fromMap({'updatedAt': ms});
      expect(porMs.updatedAt?.millisecondsSinceEpoch, ms);
    });

    test('rechaza URLs sin esquema o con esquema inválido', () {
      final config = BannerConfig(
        activo: true,
        modo: ModoBannerCatalogo.imagen,
        imagenUrl: '/assets/banner.jpg',
        videoUrl: 'ftp://cdn.ejemplo.com/promo.mp4',
        carrusel: const [
          BannerCarruselItem(id: 'rel', url: 'imagenes/banner.jpg', orden: 1),
          BannerCarruselItem(
            id: 'js',
            url: 'javascript:alert(1)',
            orden: 2,
          ),
          BannerCarruselItem(id: 'sinHost', url: 'https://', orden: 3),
        ],
      );

      expect(config.imagenUrl, isNull);
      expect(config.videoUrl, isNull);
      expect(config.carrusel, isEmpty);
      expect(config.debeMostrarse, isFalse);
    });

    test('acepta URL HTTPS válida con parámetros de Firebase Storage', () {
      const storageUrl =
          'https://firebasestorage.googleapis.com/v0/b/accesorios-ayala.appspot.com/o/banner%2Fhero.jpg?alt=media&token=abc-123';
      final config = BannerConfig(
        activo: true,
        modo: ModoBannerCatalogo.imagen,
        imagenUrl: storageUrl,
        carrusel: const [
          BannerCarruselItem(id: 'c1', url: storageUrl, orden: 1),
        ],
      );

      expect(config.imagenUrl, storageUrl);
      expect(config.carrusel.length, 1);
      expect(config.carrusel.first.tieneUrlValida, isTrue);
      expect(config.debeMostrarse, isTrue);
    });

    test(
      'descarta elementos del carrusel con claves no String y conserva los válidos',
      () {
        final config = BannerConfig.fromMap({
          'activo': true,
          'modo': 'carrusel',
          'carrusel': [
            {1: 'clave-entera', 'url': 'https://cdn.ejemplo.com/invalido.jpg'},
            {'id': 'v1', 'url': 'https://cdn.ejemplo.com/uno.jpg', 'orden': 2},
            {true: 'clave-bool'},
            {'id': 'v2', 'url': 'http://cdn.ejemplo.com/dos.jpg', 'orden': 1},
          ],
        });

        expect(config.carrusel.map((e) => e.id), ['v2', 'v1']);
        expect(config.debeMostrarse, isTrue);
      },
    );
  });
}
