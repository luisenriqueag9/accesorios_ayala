const { HttpsError } = require('firebase-functions/v2/https');

const ADMIN_UIDS = new Set([
  'sK72fiKvY0crBfUzpP4TuqnHhBE3',
  'PefdVcw7gRayt1hgCUAZt7ejgYO2',
]);

/**
 * Formatea un consecutivo entero positivo al formato FAC-XXXX.
 */
function formatearNumeroFactura(numero) {
  if (!Number.isInteger(numero) || numero < 1) {
    throw new HttpsError(
      'internal',
      'El número consecutivo de factura debe ser un entero positivo.',
    );
  }
  if (numero < 10000) {
    return `FAC-${String(numero).padStart(4, '0')}`;
  }
  return `FAC-${numero}`;
}

/**
 * Convierte un Timestamp/Date/número/ISO-string a milisegundos UTC o null.
 */
function aMilisegundosUtc(valor) {
  if (valor == null) return null;
  if (typeof valor === 'number' && Number.isFinite(valor)) {
    return Math.trunc(valor);
  }
  if (valor instanceof Date) {
    const ms = valor.getTime();
    return Number.isFinite(ms) ? ms : null;
  }
  if (typeof valor === 'string') {
    const ms = Date.parse(valor);
    return Number.isFinite(ms) ? ms : null;
  }
  if (typeof valor === 'object') {
    if (typeof valor.toMillis === 'function') {
      return valor.toMillis();
    }
    if (typeof valor.seconds === 'number') {
      const nanos = typeof valor.nanoseconds === 'number' ? valor.nanoseconds : 0;
      return valor.seconds * 1000 + Math.floor(nanos / 1e6);
    }
  }
  return null;
}

function esNumeroFinitoNoNegativo(valor) {
  return typeof valor === 'number' && Number.isFinite(valor) && valor >= 0;
}

/**
 * Calcula los importes de una venta a partir de los items y borradorFactura del pedido.
 */
function calcularImportesPedido(pedidoData) {
  const items = pedidoData.items;
  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'El pedido debe tener al menos un accesorio para facturar.',
    );
  }

  let subtotal = 0;
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (!item || typeof item !== 'object') {
      throw new HttpsError(
        'failed-precondition',
        'Uno de los accesorios del pedido tiene un formato inválido.',
      );
    }
    if (item.estadoElaboracion !== 'terminado') {
      throw new HttpsError(
        'failed-precondition',
        'Todos los accesorios del pedido deben estar terminados antes de facturar.',
      );
    }
    const cantidad = item.cantidad;
    const precioUnitario = item.precioUnitario;
    if (
      typeof cantidad !== 'number' ||
      !Number.isFinite(cantidad) ||
      !Number.isInteger(cantidad) ||
      cantidad < 1 ||
      !esNumeroFinitoNoNegativo(precioUnitario)
    ) {
      throw new HttpsError(
        'failed-precondition',
        'Los accesorios del pedido tienen cantidades o precios inválidos.',
      );
    }
    subtotal += precioUnitario * cantidad;
  }

  const borrador =
    pedidoData.borradorFactura && typeof pedidoData.borradorFactura === 'object'
      ? pedidoData.borradorFactura
      : {};

  const impuestoPorcentaje =
    borrador.impuestoPorcentaje == null ? 0 : borrador.impuestoPorcentaje;
  if (
    borrador.descuentoMayoristaActivo != null &&
    typeof borrador.descuentoMayoristaActivo !== 'boolean'
  ) {
    throw new HttpsError(
      'failed-precondition',
      'La configuración de descuento mayorista del pedido es inválida.',
    );
  }
  const descuentoMayoristaActivo = borrador.descuentoMayoristaActivo === true;
  const descuentoPorcentaje =
    borrador.descuentoPorcentaje == null ? 0 : borrador.descuentoPorcentaje;
  const costoEnvio =
    borrador.costoEnvio != null
      ? borrador.costoEnvio
      : pedidoData.costoEnvio == null
        ? 0
        : pedidoData.costoEnvio;

  if (
    !esNumeroFinitoNoNegativo(impuestoPorcentaje) ||
    !esNumeroFinitoNoNegativo(descuentoPorcentaje) ||
    descuentoPorcentaje > 100 ||
    !esNumeroFinitoNoNegativo(costoEnvio)
  ) {
    throw new HttpsError(
      'failed-precondition',
      'La configuración fiscal del pedido es inválida.',
    );
  }

  const descuentoMonto = descuentoMayoristaActivo
    ? subtotal * (descuentoPorcentaje / 100)
    : 0;
  const baseImponible = subtotal - descuentoMonto;
  const impuesto = baseImponible * (impuestoPorcentaje / 100);
  const total = baseImponible + impuesto + costoEnvio;

  return {
    subtotal,
    descuentoMayoristaActivo,
    descuentoPorcentaje,
    descuentoMonto,
    impuesto,
    envio: costoEnvio,
    total,
  };
}

/**
 * Ejecuta la facturación transaccional de un pedido en Firestore.
 * Inyecta `db`, `serverTimestamp` y `now` para permitir pruebas unitarias sin producción.
 */
async function ejecutarFacturarPedido({
  auth,
  data,
  db,
  serverTimestamp,
  now = () => new Date(),
}) {
  if (!auth || !auth.uid) {
    throw new HttpsError(
      'unauthenticated',
      'Se requiere autenticación para facturar pedidos.',
    );
  }

  if (!ADMIN_UIDS.has(auth.uid)) {
    throw new HttpsError(
      'permission-denied',
      'No tienes permisos administrativos para facturar pedidos.',
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
      'Se requiere la versión actual del pedido (updatedAtEsperado) para facturar de forma segura.',
    );
  }

  const pedidoRef = db.collection('pedidos').doc(pedidoId);
  const contadorRef = db.collection('contadores').doc('facturas');

  return db.runTransaction(async (tx) => {
    const pedidoSnap = await tx.get(pedidoRef);
    const contadorSnap = await tx.get(contadorRef);

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
        'Este pedido fue modificado por otro administrador. Recárgalo antes de facturar.',
      );
    }

    if (
      pedidoData.facturado === true ||
      pedidoData.ventaId != null ||
      pedidoData.facturaNumero != null
    ) {
      throw new HttpsError(
        'failed-precondition',
        'Este pedido ya fue facturado o está vinculado a una venta.',
      );
    }

    const clienteId =
      typeof pedidoData.clienteId === 'string' ? pedidoData.clienteId.trim() : '';
    const clienteNombre =
      typeof pedidoData.clienteNombre === 'string'
        ? pedidoData.clienteNombre.trim()
        : '';
    if (!clienteId || !clienteNombre) {
      throw new HttpsError(
        'failed-precondition',
        'El pedido no cuenta con la información mínima del cliente para facturar.',
      );
    }

    const importes = calcularImportesPedido(pedidoData);

    const contadorExiste = contadorSnap.exists;
    const contadorData = contadorSnap.data();
    let siguienteNumero;
    if (!contadorExiste) {
      siguienteNumero = 1;
    } else {
      const ultimoNumero = contadorData ? contadorData.ultimoNumero : null;
      if (!Number.isInteger(ultimoNumero) || ultimoNumero < 1) {
        throw new HttpsError(
          'internal',
          'El contador consecutivo de facturas tiene un formato inválido en Firestore.',
        );
      }
      siguienteNumero = ultimoNumero + 1;
    }

    const facturaNumero = formatearNumeroFactura(siguienteNumero);
    const ventaRef = db.collection('ventas').doc(facturaNumero);
    const ventaSnap = await tx.get(ventaRef);
    if (ventaSnap.exists) {
      throw new HttpsError(
        'already-exists',
        `El número de factura ${facturaNumero} ya existe en la colección de ventas.`,
      );
    }

    const fechaEmision = now();
    const ventaMap = {
      id: facturaNumero,
      clienteId,
      clienteNombre,
      fecha: fechaEmision.toISOString(),
      subtotal: importes.subtotal,
      impuesto: importes.impuesto,
      total: importes.total,
      envio: importes.envio,
      descuentoMayoristaActivo: importes.descuentoMayoristaActivo,
      descuentoPorcentaje: importes.descuentoPorcentaje,
      descuentoMonto: importes.descuentoMonto,
    };

    const marcaServidor = serverTimestamp();
    const payloadContador = {
      ultimoNumero: siguienteNumero,
      ultimaVentaId: facturaNumero,
      ultimoPedidoId: pedidoId,
      updatedAt: marcaServidor,
    };

    if (contadorExiste) {
      tx.update(contadorRef, payloadContador);
    } else {
      tx.set(contadorRef, payloadContador);
    }

    tx.set(ventaRef, ventaMap);
    tx.update(pedidoRef, {
      facturado: true,
      ventaId: facturaNumero,
      facturaNumero,
      fechaFacturacion: marcaServidor,
      updatedAt: marcaServidor,
    });

    return {
      ok: true,
      pedidoId,
      facturaNumero,
      ventaId: facturaNumero,
      subtotal: importes.subtotal,
      descuentoMonto: importes.descuentoMonto,
      impuesto: importes.impuesto,
      envio: importes.envio,
      total: importes.total,
    };
  });
}

module.exports = {
  ADMIN_UIDS,
  formatearNumeroFactura,
  aMilisegundosUtc,
  calcularImportesPedido,
  ejecutarFacturarPedido,
};
