import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/categoria.dart';

/// Controlador para administrar categorías de productos en Firestore.
class CategoriaController {
  static const String collection = 'categorias';

  static int _compararCategorias(Categoria a, Categoria b) {
    final ordenCmp = a.orden.compareTo(b.orden);
    if (ordenCmp != 0) return ordenCmp;

    final nombreCmp = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    if (nombreCmp != 0) return nombreCmp;

    return a.id.compareTo(b.id);
  }

  /// Carga todas las categorías ordenadas de forma determinista por `orden`,
  /// `nombre` e `id`. Si [soloVisibles] es `true`, filtra únicamente las activas.
  static Future<List<Categoria>> cargarCategorias({
    bool soloVisibles = false,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseFirestore.instance;
    final snapshot = await db.collection(collection).get();

    final categorias = snapshot.docs.map((doc) {
      return Categoria.fromMap({
        ...doc.data(),
        'id': doc.id,
      });
    }).where((c) => !soloVisibles || c.visible).toList();

    categorias.sort(_compararCategorias);
    return categorias;
  }

  /// Guarda una categoría nueva o existente. Si `categoria.id` está vacío,
  /// genera un identificador nuevo en Firestore; si ya existe, conserva su ID.
  static Future<Categoria> guardarCategoria(
    Categoria categoria, {
    FirebaseFirestore? firestore,
  }) async {
    final nombreLimpio = categoria.nombre.trim();
    if (nombreLimpio.isEmpty) {
      throw ArgumentError.value(
        categoria.nombre,
        'nombre',
        'El nombre de la categoría no puede estar vacío.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final idLimpio = categoria.id.trim();
    final docRef = idLimpio.isEmpty
        ? db.collection(collection).doc()
        : db.collection(collection).doc(idLimpio);

    final normalizada = Categoria(
      id: docRef.id,
      nombre: nombreLimpio,
      orden: categoria.orden,
      visible: categoria.visible,
    );

    await docRef.set(normalizada.toMap());
    return normalizada;
  }

  /// Actualiza una categoría existente conservando exactamente su `id`.
  static Future<Categoria> actualizarCategoria(
    Categoria categoria, {
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = categoria.id.trim();
    if (idLimpio.isEmpty) {
      throw ArgumentError.value(
        categoria.id,
        'id',
        'El identificador de la categoría es obligatorio para actualizar.',
      );
    }

    final nombreLimpio = categoria.nombre.trim();
    if (nombreLimpio.isEmpty) {
      throw ArgumentError.value(
        categoria.nombre,
        'nombre',
        'El nombre de la categoría no puede estar vacío.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final normalizada = Categoria(
      id: idLimpio,
      nombre: nombreLimpio,
      orden: categoria.orden,
      visible: categoria.visible,
    );

    await db.collection(collection).doc(idLimpio).update(normalizada.toMap());
    return normalizada;
  }

  /// Actualiza únicamente el campo `visible` sin modificar el resto del documento.
  static Future<void> cambiarVisibilidad(
    String categoriaId,
    bool visible, {
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = categoriaId.trim();
    if (idLimpio.isEmpty) {
      throw ArgumentError.value(
        categoriaId,
        'categoriaId',
        'El identificador de la categoría no puede estar vacío.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    await db.collection(collection).doc(idLimpio).update({'visible': visible});
  }

  /// Actualiza únicamente el campo `orden` sin modificar el resto del documento.
  static Future<void> actualizarOrden(
    String categoriaId,
    int orden, {
    FirebaseFirestore? firestore,
  }) async {
    final idLimpio = categoriaId.trim();
    if (idLimpio.isEmpty) {
      throw ArgumentError.value(
        categoriaId,
        'categoriaId',
        'El identificador de la categoría no puede estar vacío.',
      );
    }

    final db = firestore ?? FirebaseFirestore.instance;
    await db.collection(collection).doc(idLimpio).update({'orden': orden});
  }
}
