const { HttpsError } = require('firebase-functions/v2/https');
const { ADMIN_UIDS, aMilisegundosUtc } = require('./facturar_pedido_core');

/**
 * Ejecuta la transición transaccional de envío `pendiente -> enviado` sobre un pedido.
 * Inyecta `db` y `serverTimestamp` para permitir pruebas unitarias sin producción.
 */
async function ejecutarMarcarPedidoEnviado({
  auth,
  data,
  db,
  serverTimestamp,
}) {
  if (!auth || !auth.uid) {
    throw new HttpsError(
      'unauthenticated',
      'Se requiere autenticación para marcar pedidos como enviados.',
    );
  }

  if (!ADMIN_UIDS.has(auth.uid)) {
    throw new HttpsError(
      'permission-denied',
      'No tienes permisos administrativos para marcar pedidos como enviados.',
    );
  }

  const payload = data && typeof data === 'object' ? data : {};
  const pedidoId =
    typeof payload.pedidoId === 'string' ? payload.pedidoId.trim() : '';
  if (!pedidoId) {
    throw new HttpsError(
      'invalid-argument',
      'El identificador del pedido es obligatorio.',
    );
  }

  const marcaEsperadaMs = aMilisegundosUtc(
    payload.updatedAtEsperadoMs ?? payload.updatedAtEsperado,
  );
  if (marcaEsperadaMs == null) {
    throw new HttpsError(
      'invalid-argument',
      'Se requiere la versión actual del pedido (updatedAtEsperado) para actualizar el envío de forma segura.',
    );
  }

  const pedidoRef = db.collection('pedidos').doc(pedidoId);

  return db.runTransaction(async (tx) => {
    const pedidoSnap = await tx.get(pedidoRef);
    const pedidoData = pedidoSnap.data();

    if (!pedidoSnap.exists || !pedidoData) {
      throw new HttpsError(
        'not-found',
        'El pedido no existe o fue eliminado de Firestore.',
      );
    }

    const marcaActualMs = aMilisegundosUtc(pedidoData.updatedAt);
    if (marcaActualMs == null || marcaActualMs !== marcaEsperadaMs) {
      throw new HttpsError(
        'failed-precondition',
        'Este pedido fue modificado por otro administrador. Recárgalo antes de marcarlo como enviado.',
      );
    }

    const estadoEnvioRaw = pedidoData.estadoEnvio;
    if (estadoEnvioRaw != null && typeof estadoEnvioRaw !== 'string') {
      throw new HttpsError(
        'failed-precondition',
        'El estado de envío del pedido tiene un formato inválido.',
      );
    }

    const estadoEnvio = estadoEnvioRaw == null ? 'pendiente' : estadoEnvioRaw;
    if (estadoEnvio !== 'pendiente') {
      throw new HttpsError(
        'failed-precondition',
        estadoEnvio === 'enviado'
          ? 'Este pedido ya fue marcado como enviado.'
          : 'Solo los pedidos con envío pendiente pueden marcarse como enviados.',
      );
    }

    const items = pedidoData.items;
    if (!Array.isArray(items) || items.length === 0) {
      throw new HttpsError(
        'failed-precondition',
        'El pedido debe tener al menos un artículo para marcarse como enviado.',
      );
    }

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (!item || typeof item !== 'object' || item.estadoElaboracion !== 'terminado') {
        throw new HttpsError(
          'failed-precondition',
          'Todos los artículos del pedido deben estar terminados antes de marcarlo como enviado.',
        );
      }
    }

    const marcaServidor = serverTimestamp();
    tx.update(pedidoRef, {
      estadoEnvio: 'enviado',
      fechaEnvio: marcaServidor,
      updatedAt: marcaServidor,
    });

    return {
      ok: true,
      pedidoId,
      estadoEnvio: 'enviado',
    };
  });
}

module.exports = {
  ejecutarMarcarPedidoEnviado,
};
