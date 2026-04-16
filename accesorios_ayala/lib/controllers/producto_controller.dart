import 'package:flutter/foundation.dart';
import '../models/producto.dart';
import 'package:sqflite/sqflite.dart' as sql;


// ================= WEB (IndexedDB) =================
import 'package:idb_shim/idb.dart' as idb;
import 'package:idb_shim/idb_browser.dart';

// ================= LOCAL (SQLite) =================
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart';

class ProductoController {
  // ======================
  // API PÚBLICA
  // ======================

  static Future<void> guardarProducto(Producto producto) async {
    if (kIsWeb) {
      await _guardarWeb(producto);
    } else {
      await _guardarLocal(producto);
    }
  }

  static Future<List<Producto>> cargarProductos() async {
    if (kIsWeb) {
      return await _cargarWeb();
    } else {
      return await _cargarLocal();
    }
  }

  static Future<void> eliminarProducto(String id) async {
    if (kIsWeb) {
      await _eliminarWeb(id);
    } else {
      await _eliminarLocal(id);
    }
  }

  // =================================================
  // WEB — IndexedDB
  // =================================================

  static const _dbNameWeb = 'productos_db';
  static const _storeWeb = 'productos';

  static Future<idb.Database> _openWebDb() async {
    final factory = getIdbFactory()!;
    return await factory.open(
      _dbNameWeb,
      version: 1,
      onUpgradeNeeded: (e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeWeb)) {
          db.createObjectStore(_storeWeb, keyPath: 'id');
        }
      },
    );
  }

  static Future<void> _guardarWeb(Producto producto) async {
    final db = await _openWebDb();
    final txn = db.transaction(_storeWeb, idb.idbModeReadWrite);
    final store = txn.objectStore(_storeWeb);

    await store.put({
      'id': producto.id,
      'nombre': producto.nombre,
      'descripcion': producto.descripcion,
      'precio': producto.precio,
      'imagenBase64': producto.imagenBase64,
    });

    await txn.completed;
    db.close();
  }

  static Future<List<Producto>> _cargarWeb() async {
    final db = await _openWebDb();
    final txn = db.transaction(_storeWeb, idb.idbModeReadOnly);
    final store = txn.objectStore(_storeWeb);

    final List<Producto> productos = [];
    final cursorStream = store.openCursor(autoAdvance: true);

    await for (final cursor in cursorStream) {
      final data = Map<String, dynamic>.from(cursor.value as Map);
      productos.add(Producto.fromMap(data));
    }

    await txn.completed;
    db.close();
    return productos;
  }

  static Future<void> _eliminarWeb(String id) async {
    final db = await _openWebDb();
    final txn = db.transaction(_storeWeb, idb.idbModeReadWrite);
    final store = txn.objectStore(_storeWeb);
    await store.delete(id);
    await txn.completed;
    db.close();
  }

  // =================================================
  // LOCAL — SQLite (iOS / Windows / Android)
  // =================================================

  static sql.Database? _db;

  static Future<sql.Database> _openLocalDb() async {
    if (_db != null) return _db!;

    final path = join(await sql.getDatabasesPath(), 'productos.db');


    _db = await sql.openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE productos (
            id TEXT PRIMARY KEY,
            nombre TEXT,
            descripcion TEXT,
            precio REAL,
            imagenBase64 TEXT
          )
        ''');
      },
    );

    return _db!;
  }

  static Future<void> _guardarLocal(Producto producto) async {
    final db = await _openLocalDb();
    await db.insert(
      'productos',
      {
        'id': producto.id,
        'nombre': producto.nombre,
        'descripcion': producto.descripcion,
        'precio': producto.precio,
        'imagenBase64': producto.imagenBase64,
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  static Future<List<Producto>> _cargarLocal() async {
    final db = await _openLocalDb();
    final maps = await db.query('productos');

    return maps
        .map((m) => Producto.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<void> _eliminarLocal(String id) async {
    final db = await _openLocalDb();
    await db.delete(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
