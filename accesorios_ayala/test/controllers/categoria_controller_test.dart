import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/controllers/categoria_controller.dart';
import 'package:accesorios_ayala/models/categoria.dart';

void main() {
  group('CategoriaController', () {
    test(
      'cargarCategorias ordena por orden y desempata de forma determinista por nombre e id',
      () async {
        final db = _FakeFirestore(
          documentos: {
            'cat-b': {'id': 'cat-b', 'nombre': 'Pulseras', 'orden': 2, 'visible': true},
            'cat-a': {'id': 'cat-a', 'nombre': 'Aretes', 'orden': 2, 'visible': true},
            'cat-1': {'id': 'cat-1', 'nombre': 'Cadenas', 'orden': 1, 'visible': false},
            'cat-c': {'nombre': 'Aretes', 'orden': 2, 'visible': true},
          },
        );

        final categorias = await CategoriaController.cargarCategorias(
          firestore: db,
        );

        expect(categorias.map((c) => c.id).toList(), [
          'cat-1',
          'cat-a',
          'cat-c',
          'cat-b',
        ]);
        expect(categorias.first.visible, isFalse);
      },
    );

    test('cargarCategorias con soloVisibles filtra categorías ocultas', () async {
      final db = _FakeFirestore(
        documentos: {
          'cat-1': {'id': 'cat-1', 'nombre': 'Pulseras', 'orden': 1, 'visible': true},
          'cat-2': {'id': 'cat-2', 'nombre': 'Oculta', 'orden': 2, 'visible': false},
          'cat-3': {'id': 'cat-3', 'nombre': 'Collares', 'orden': 3, 'visible': true},
        },
      );

      final visibles = await CategoriaController.cargarCategorias(
        soloVisibles: true,
        firestore: db,
      );

      expect(visibles.map((c) => c.id).toList(), ['cat-1', 'cat-3']);
    });

    test('guardarCategoria crea nueva categoría con ID generado y limpia espacios', () async {
      final db = _FakeFirestore();

      final guardada = await CategoriaController.guardarCategoria(
        Categoria(
          id: '',
          nombre: '  Grabados láser  ',
          orden: 5,
          visible: true,
        ),
        firestore: db,
      );

      expect(guardada.id, isNotEmpty);
      expect(guardada.nombre, 'Grabados láser');
      expect(db.documentos.length, 1);
      expect(db.documentos[guardada.id], {
        'id': guardada.id,
        'nombre': 'Grabados láser',
        'orden': 5,
        'visible': true,
      });
    });

    test('actualizarCategoria conserva el ID existente sin duplicar documentos', () async {
      final db = _FakeFirestore(
        documentos: {
          'cat-1': {'id': 'cat-1', 'nombre': 'Pulseras', 'orden': 1, 'visible': true},
        },
      );

      final actualizada = await CategoriaController.actualizarCategoria(
        Categoria(
          id: 'cat-1',
          nombre: 'Pulseras Premium',
          orden: 3,
          visible: false,
        ),
        firestore: db,
      );

      expect(actualizada.id, 'cat-1');
      expect(db.documentos.length, 1);
      expect(db.documentos['cat-1'], {
        'id': 'cat-1',
        'nombre': 'Pulseras Premium',
        'orden': 3,
        'visible': false,
      });
    });

    test('rechaza nombres vacíos al guardar o actualizar y ID vacío al actualizar', () async {
      final db = _FakeFirestore();

      await expectLater(
        () => CategoriaController.guardarCategoria(
          Categoria(id: '', nombre: '   ', orden: 1),
          firestore: db,
        ),
        throwsArgumentError,
      );

      await expectLater(
        () => CategoriaController.actualizarCategoria(
          Categoria(id: 'cat-1', nombre: '', orden: 1),
          firestore: db,
        ),
        throwsArgumentError,
      );

      await expectLater(
        () => CategoriaController.actualizarCategoria(
          Categoria(id: '   ', nombre: 'Válida', orden: 1),
          firestore: db,
        ),
        throwsArgumentError,
      );
    });

    test('cambiarVisibilidad y actualizarOrden actualizan únicamente el campo correspondiente', () async {
      final db = _FakeFirestore(
        documentos: {
          'cat-1': {'id': 'cat-1', 'nombre': 'Pulseras', 'orden': 1, 'visible': true},
        },
      );

      await CategoriaController.cambiarVisibilidad('cat-1', false, firestore: db);
      expect(db.documentos['cat-1']?['visible'], isFalse);
      expect(db.documentos['cat-1']?['nombre'], 'Pulseras');
      expect(db.documentos['cat-1']?['orden'], 1);

      await CategoriaController.actualizarOrden('cat-1', 7, firestore: db);
      expect(db.documentos['cat-1']?['orden'], 7);
      expect(db.documentos['cat-1']?['visible'], isFalse);
      expect(db.documentos['cat-1']?['nombre'], 'Pulseras');
    });

    test('propaga errores de Firestore al consultar o modificar', () async {
      final db = _FakeFirestore(
        errorEnOperacion: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      await expectLater(
        () => CategoriaController.cargarCategorias(firestore: db),
        throwsA(isA<FirebaseException>()),
      );

      await expectLater(
        () => CategoriaController.cambiarVisibilidad('cat-1', false, firestore: db),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('actualizarCategoria falla con not-found y no crea documento si el ID no existe', () async {
      final db = _FakeFirestore();

      await expectLater(
        () => CategoriaController.actualizarCategoria(
          Categoria(
            id: 'cat-inexistente',
            nombre: 'Nueva',
            orden: 1,
            visible: true,
          ),
          firestore: db,
        ),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
        ),
      );

      expect(db.documentos, isEmpty);
    });

    test('cargarCategorias usa siempre doc.id aunque el mapa contenga otro id', () async {
      final db = _FakeFirestore(
        documentos: {
          'doc-real-1': {
            'id': 'id-desfasado',
            'nombre': 'Pulseras',
            'orden': 1,
            'visible': true,
          },
        },
      );

      final categorias = await CategoriaController.cargarCategorias(
        firestore: db,
      );

      expect(categorias, hasLength(1));
      expect(categorias.single.id, 'doc-real-1');
      expect(categorias.single.nombre, 'Pulseras');
    });
  });
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore({
    Map<String, Map<String, dynamic>>? documentos,
    this.errorEnOperacion,
  }) : documentos = {
          if (documentos != null)
            for (final e in documentos.entries)
              e.key: Map<String, dynamic>.from(e.value),
        };

  final Map<String, Map<String, dynamic>> documentos;
  final Object? errorEnOperacion;
  int _secuenciaId = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath != CategoriaController.collection) {
      throw StateError('Colección inesperada: $collectionPath');
    }
    return _FakeCollectionReference(this);
  }
}

// ignore: subtype_of_sealed_class
class _FakeCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCollectionReference(this._db);

  final _FakeFirestore _db;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final id = (path == null || path.isEmpty)
        ? 'auto-${++_db._secuenciaId}'
        : path;
    return _FakeDocumentReference(_db, id);
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (_db.errorEnOperacion != null) {
      throw _db.errorEnOperacion!;
    }
    final docs = _db.documentos.entries
        .map((e) => _FakeQueryDocumentSnapshot(e.key, e.value))
        .toList();
    return _FakeQuerySnapshot(docs);
  }
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
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (_db.errorEnOperacion != null) {
      throw _db.errorEnOperacion!;
    }
    _db.documentos[_id] = Map<String, dynamic>.from(data);
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (_db.errorEnOperacion != null) {
      throw _db.errorEnOperacion!;
    }
    final actual = _db.documentos[_id];
    if (actual == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
      );
    }
    data.forEach((key, value) {
      actual[key.toString()] = value;
    });
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
