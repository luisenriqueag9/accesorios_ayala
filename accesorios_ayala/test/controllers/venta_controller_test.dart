import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:accesorios_ayala/controllers/venta_controller.dart';

void main() {
  group('VentaController.cargarFacturas', () {
    test(
      'devuelve únicamente documentos FAC-*, excluye ventas manuales y no consulta pedidos',
      () async {
        final db = _FakeFirestore(
          documentos: {
            'FAC-0001': {
              'id': 'FAC-0001',
              'clienteId': 'cli-1',
              'clienteNombre': 'Ana López',
              'fecha': '2026-11-10T10:00:00.000Z',
              'subtotal': 500.0,
              'impuesto': 0.0,
              'total': 620.0,
              'envio': 120.0,
              'descuentoMayoristaActivo': false,
              'descuentoPorcentaje': 0.0,
              'descuentoMonto': 0.0,
            },
            'MAN-0001': {
              'id': 'MAN-0001',
              'clienteId': 'cli-2',
              'clienteNombre': 'Venta Manual',
              // Fecha incompatible en venta manual: no debe interferir con FAC-*.
              'fecha': null,
              'subtotal': 300.0,
              'impuesto': 0.0,
              'total': 300.0,
            },
            'REC-2026-01': {
              'id': 'REC-2026-01',
              'clienteId': 'cli-3',
              'clienteNombre': 'Otro Recibo',
              'fecha': 'fecha-no-iso',
              'total': 150.0,
            },
            'FAC-0002': {
              'id': 'FAC-0002',
              'clienteId': 'cli-4',
              'clienteNombre': 'Carlos Pérez',
              'fecha': '2026-11-12T15:30:00.000Z',
              'subtotal': 800.0,
              'impuesto': 0.0,
              'total': 920.0,
              'envio': 120.0,
              'descuentoMayoristaActivo': false,
              'descuentoPorcentaje': 0.0,
              'descuentoMonto': 0.0,
            },
          },
        );

        final facturas = await VentaController.cargarFacturas(firestore: db);

        expect(db.coleccionesConsultadas, ['ventas']);
        expect(facturas.map((f) => f.id).toList(), ['FAC-0002', 'FAC-0001']);
      },
    );

    test(
      'ordena las facturas de más reciente a más antigua y recupera clienteNombre, id, fecha y total',
      () async {
        final db = _FakeFirestore(
          documentos: {
            'FAC-0001': {
              'id': 'FAC-0001',
              'clienteId': 'cli-1',
              'clienteNombre': 'Primera',
              'fecha': '2026-11-01T08:00:00.000Z',
              'subtotal': 100.0,
              'impuesto': 0.0,
              'total': 100.0,
            },
            'FAC-0003': {
              'id': 'FAC-0003',
              'clienteId': 'cli-3',
              'clienteNombre': 'Tercera',
              'fecha': '2026-11-15T18:45:00.000Z',
              'subtotal': 300.0,
              'impuesto': 45.0,
              'total': 345.0,
            },
            'FAC-0002': {
              'id': 'FAC-0002',
              'clienteId': 'cli-2',
              'clienteNombre': 'Segunda',
              'fecha': '2026-11-10T12:00:00.000Z',
              'subtotal': 200.0,
              'impuesto': 0.0,
              'total': 200.0,
            },
          },
        );

        final facturas = await VentaController.cargarFacturas(firestore: db);

        expect(facturas, hasLength(3));
        expect(facturas[0].id, 'FAC-0003');
        expect(facturas[0].clienteNombre, 'Tercera');
        expect(facturas[0].fecha, DateTime.parse('2026-11-15T18:45:00.000Z'));
        expect(facturas[0].total, 345.0);

        expect(facturas[1].id, 'FAC-0002');
        expect(facturas[2].id, 'FAC-0001');
      },
    );

    test('devuelve una lista vacía cuando no existen facturas FAC-*', () async {
      final dbVacia = _FakeFirestore(documentos: {});
      expect(await VentaController.cargarFacturas(firestore: dbVacia), isEmpty);

      final dbSoloManuales = _FakeFirestore(
        documentos: {
          'MAN-0001': {
            'id': 'MAN-0001',
            'clienteId': 'cli-1',
            'clienteNombre': 'Manual',
            'fecha': '2026-11-14T10:00:00.000Z',
            'subtotal': 100.0,
            'impuesto': 0.0,
            'total': 100.0,
          },
        },
      );
      expect(
        await VentaController.cargarFacturas(firestore: dbSoloManuales),
        isEmpty,
      );
    });

    test(
      'propaga errores de Firestore (permisos o conexión) sin devolver lista vacía',
      () async {
        final dbPermisos = _FakeFirestore(
          errorEnGet: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Missing or insufficient permissions.',
          ),
        );

        await expectLater(
          () => VentaController.cargarFacturas(firestore: dbPermisos),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );

        final dbConexion = _FakeFirestore(
          errorEnGet: FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Service unavailable.',
          ),
        );

        await expectLater(
          () => VentaController.cargarFacturas(firestore: dbConexion),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'unavailable',
            ),
          ),
        );
      },
    );

    test('utiliza el ID del documento cuando falta el campo id o está vacío', () async {
      final db = _FakeFirestore(
        documentos: {
          'FAC-0010': {
            'clienteId': 'cli-10',
            'clienteNombre': 'Cliente Sin Campo ID',
            'fecha': '2026-11-14T09:00:00.000Z',
            'subtotal': 250.0,
            'impuesto': 0.0,
            'total': 250.0,
          },
          'FAC-0011': {
            'id': '   ',
            'clienteId': 'cli-11',
            'clienteNombre': 'Cliente ID Vacío',
            'fecha': '2026-11-15T09:00:00.000Z',
            'subtotal': 300.0,
            'impuesto': 0.0,
            'total': 300.0,
          },
        },
      );

      final facturas = await VentaController.cargarFacturas(firestore: db);

      expect(facturas, hasLength(2));
      expect(facturas[0].id, 'FAC-0011');
      expect(facturas[1].id, 'FAC-0010');
    });

    test('acepta fechas almacenadas como Timestamp', () async {
      final fechaUtc = DateTime.utc(2026, 11, 15, 16, 20, 30);
      final db = _FakeFirestore(
        documentos: {
          'FAC-0020': {
            'id': 'FAC-0020',
            'clienteId': 'cli-20',
            'clienteNombre': 'Cliente Timestamp',
            'fecha': Timestamp.fromDate(fechaUtc),
            'subtotal': 400.0,
            'impuesto': 0.0,
            'total': 400.0,
          },
        },
      );

      final facturas = await VentaController.cargarFacturas(firestore: db);

      expect(facturas, hasLength(1));
      expect(facturas.single.id, 'FAC-0020');
      expect(facturas.single.fecha.toUtc(), fechaUtc);
    });

    test(
      'maneja explícitamente documentos FAC-* con datos inválidos sin ocultar el error',
      () async {
        final dbFechaInvalida = _FakeFirestore(
          documentos: {
            'FAC-0030': {
              'id': 'FAC-0030',
              'clienteId': 'cli-30',
              'clienteNombre': 'Factura Corrupta',
              'fecha': 'no-es-una-fecha',
              'total': 100.0,
            },
          },
        );

        await expectLater(
          () => VentaController.cargarFacturas(firestore: dbFechaInvalida),
          throwsFormatException,
        );

        final dbSinFecha = _FakeFirestore(
          documentos: {
            'FAC-0031': {
              'id': 'FAC-0031',
              'clienteId': 'cli-31',
              'clienteNombre': 'Factura Sin Fecha',
              'total': 100.0,
            },
          },
        );

        await expectLater(
          () => VentaController.cargarFacturas(firestore: dbSinFecha),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  _FakeFirestore({
    Map<String, Map<String, dynamic>>? documentos,
    this.errorEnGet,
  }) : documentos = documentos ?? const {};

  final Map<String, Map<String, dynamic>> documentos;
  final Object? errorEnGet;
  final List<String> coleccionesConsultadas = [];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    coleccionesConsultadas.add(collectionPath);
    if (collectionPath != VentaController.collection) {
      throw StateError('Acceso inesperado a colección: $collectionPath');
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
    return _FakeQuery(_db).where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isLessThan: isLessThan,
      isLessThanOrEqualTo: isLessThanOrEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
      arrayContains: arrayContains,
      arrayContainsAny: arrayContainsAny,
      whereIn: whereIn,
      whereNotIn: whereNotIn,
      isNull: isNull,
    );
  }
}

// ignore: subtype_of_sealed_class
class _FakeQuery extends Fake implements Query<Map<String, dynamic>> {
  _FakeQuery(this._db, {this.minId, this.maxIdExclusivo});

  final _FakeFirestore _db;
  final String? minId;
  final String? maxIdExclusivo;

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
    if (field != FieldPath.documentId) {
      throw UnimplementedError('Filtro no soportado en _FakeQuery: $field');
    }

    return _FakeQuery(
      _db,
      minId: isGreaterThanOrEqualTo as String? ?? minId,
      maxIdExclusivo: isLessThan as String? ?? maxIdExclusivo,
    );
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    if (_db.errorEnGet != null) {
      throw _db.errorEnGet!;
    }

    final docsFiltrados = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final entry in _db.documentos.entries) {
      final id = entry.key;
      if (minId != null && id.compareTo(minId!) < 0) continue;
      if (maxIdExclusivo != null && id.compareTo(maxIdExclusivo!) >= 0) {
        continue;
      }
      docsFiltrados.add(_FakeQueryDocumentSnapshot(id, entry.value));
    }

    return _FakeQuerySnapshot(docsFiltrados);
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
  Map<String, dynamic> data() => Map<String, dynamic>.from(_data);
}
