const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { ejecutarFacturarPedido } = require('./facturar_pedido_core');

function obtenerDb() {
  const defaultApp =
    getApps().find((app) => app.name === '[DEFAULT]') ?? initializeApp();
  return getFirestore(defaultApp);
}

/**
 * Función callable temporal para verificar la infraestructura de Cloud Functions v2.
 */
exports.verificarInfraestructura = onCall(
  {
    region: 'us-central1',
  },
  (request) => {
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'Se requiere autenticación para verificar la infraestructura.',
      );
    }

    return {
      ok: true,
      servicio: 'cloud-functions-v2',
      region: 'us-central1',
      mensaje: 'Infraestructura de Cloud Functions operativa.',
    };
  },
);

/**
 * Factura un pedido terminado en una única transacción atómica en servidor.
 */
exports.facturarPedido = onCall(
  {
    region: 'us-central1',
  },
  async (request) => {
    const db = obtenerDb();
    return ejecutarFacturarPedido({
      auth: request.auth,
      data: request.data,
      db,
      serverTimestamp: () => FieldValue.serverTimestamp(),
    });
  },
);
