import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const PROJECT_ID = 'accesorios-ayala';
const ADMIN_UID = 'sK72fiKvY0crBfUzpP4TuqnHhBE3';
const UNAUTHORIZED_UID = 'usuario_no_autorizado_999';
const TEST_TIME = '2026-11-14T20:00:00Z';

const CONTADOR_PATH = '/databases/(default)/documents/contadores/facturas';
const PEDIDO_1_ID = 'ped-fac-1';
const PEDIDO_2_ID = 'ped-fac-2';
const PEDIDO_1_PATH = `/databases/(default)/documents/pedidos/${PEDIDO_1_ID}`;
const PEDIDO_2_PATH = `/databases/(default)/documents/pedidos/${PEDIDO_2_ID}`;
const PEDIDO_20_ID = 'ped-fac-20';
const PEDIDO_21_ID = 'ped-fac-21';
const PEDIDO_20_PATH = `/databases/(default)/documents/pedidos/${PEDIDO_20_ID}`;
const PEDIDO_21_PATH = `/databases/(default)/documents/pedidos/${PEDIDO_21_ID}`;
const VENTA_1_PATH = '/databases/(default)/documents/ventas/FAC-0001';
const VENTA_2_PATH = '/databases/(default)/documents/ventas/FAC-0002';
const VENTA_20_PATH = '/databases/(default)/documents/ventas/FAC-0003';
const VENTA_21_PATH = '/databases/(default)/documents/ventas/FAC-0004';
const VENTA_MANUAL_PATH = '/databases/(default)/documents/ventas/1763123456789';

function crearItemsTerminados(cantidadItems, precioUnitario = 25) {
  return Array.from({ length: cantidadItems }, (_, idx) => ({
    itemId: `item-${idx + 1}`,
    productoId: `prod-${idx + 1}`,
    nombre: `Accesorio ${idx + 1}`,
    cantidad: 1,
    precioUnitario,
    imageUrl: null,
    notaPersonalizacion: '',
    estadoElaboracion: 'terminado',
  }));
}

function crearPedidoBase({
  id = PEDIDO_1_ID,
  numeroPedido = 'PED-0001',
  estadoItem = 'terminado',
  facturado = false,
  ventaId = null,
  facturaNumero = null,
} = {}) {
  return {
    id,
    numeroPedido,
    clienteId: 'cli-1',
    clienteNombre: 'Ana López',
    clienteTelefono: '9999-0000',
    clienteDireccion: 'Col. Centro',
    clienteDepartamento: 'Cortés',
    items: [
      {
        itemId: 'item-1',
        productoId: 'prod-1',
        nombre: 'Pulsera Dorada',
        cantidad: 2,
        precioUnitario: 250,
        imageUrl: null,
        notaPersonalizacion: '',
        estadoElaboracion: estadoItem,
      },
    ],
    keywordsBusqueda: ['ped-0001', 'ana', 'lopez', 'pulsera', 'dorada'],
    estadoProduccion: estadoItem,
    estadoEnvio: 'pendiente',
    costoEnvio: 120,
    borradorFactura: {
      impuestoPorcentaje: 15,
      descuentoMayoristaActivo: true,
      descuentoPorcentaje: 20,
      costoEnvio: 120,
      subtotalEstimado: 500,
      totalEstimado: 580,
    },
    facturado,
    ventaId,
    facturaNumero,
    fechaFacturacion: null,
    updatedAt: '2026-11-14T18:00:00Z',
  };
}

function crearVentaFac(facturaNumero) {
  return {
    id: facturaNumero,
    clienteId: 'cli-1',
    clienteNombre: 'Ana López',
    fecha: '2026-11-14T20:00:00.000',
    subtotal: 500.0,
    impuesto: 60.0,
    total: 580.0,
    envio: 120.0,
    descuentoMayoristaActivo: true,
    descuentoPorcentaje: 20.0,
    descuentoMonto: 100.0,
  };
}

function mockFn(fn, argPath, result) {
  return {
    function: fn,
    args: [{ exactValue: argPath }],
    result,
  };
}

const pedido1Antes = crearPedidoBase({ id: PEDIDO_1_ID, numeroPedido: 'PED-0001' });
const pedido1Despues = {
  ...pedido1Antes,
  facturado: true,
  ventaId: 'FAC-0001',
  facturaNumero: 'FAC-0001',
  fechaFacturacion: TEST_TIME,
  updatedAt: TEST_TIME,
};
const contador1 = {
  ultimoNumero: 1,
  ultimaVentaId: 'FAC-0001',
  ultimoPedidoId: PEDIDO_1_ID,
  updatedAt: TEST_TIME,
};
const venta1 = crearVentaFac('FAC-0001');

const pedido2Antes = crearPedidoBase({ id: PEDIDO_2_ID, numeroPedido: 'PED-0002' });
const pedido2Despues = {
  ...pedido2Antes,
  facturado: true,
  ventaId: 'FAC-0002',
  facturaNumero: 'FAC-0002',
  fechaFacturacion: TEST_TIME,
  updatedAt: TEST_TIME,
};
const contador2 = {
  ultimoNumero: 2,
  ultimaVentaId: 'FAC-0002',
  ultimoPedidoId: PEDIDO_2_ID,
  updatedAt: TEST_TIME,
};
const venta2 = crearVentaFac('FAC-0002');

const mocksFac1 = [
  mockFn('exists', VENTA_1_PATH, { value: false }),
  mockFn('existsAfter', VENTA_1_PATH, { value: true }),
  mockFn('exists', PEDIDO_1_PATH, { value: true }),
  mockFn('existsAfter', PEDIDO_1_PATH, { value: true }),
  mockFn('get', PEDIDO_1_PATH, { value: { data: pedido1Antes } }),
  mockFn('getAfter', PEDIDO_1_PATH, { value: { data: pedido1Despues } }),
  mockFn('existsAfter', CONTADOR_PATH, { value: true }),
  mockFn('getAfter', CONTADOR_PATH, { value: { data: contador1 } }),
];

const mocksFac2 = [
  mockFn('exists', VENTA_2_PATH, { value: false }),
  mockFn('existsAfter', VENTA_2_PATH, { value: true }),
  mockFn('exists', PEDIDO_2_PATH, { value: true }),
  mockFn('existsAfter', PEDIDO_2_PATH, { value: true }),
  mockFn('get', PEDIDO_2_PATH, { value: { data: pedido2Antes } }),
  mockFn('getAfter', PEDIDO_2_PATH, { value: { data: pedido2Despues } }),
  mockFn('existsAfter', CONTADOR_PATH, { value: true }),
  mockFn('getAfter', CONTADOR_PATH, { value: { data: contador2 } }),
];

const cases = [
  {
    label: '1a. DENY: admin no puede crear contadores/facturas directamente',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: CONTADOR_PATH, method: 'create', time: TEST_TIME, resource: { data: contador1 } },
    functionMocks: mocksFac1,
  },
  {
    label: '1b. DENY: admin no puede crear ventas/FAC-0001 directamente',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: VENTA_1_PATH, method: 'create', time: TEST_TIME, resource: { data: venta1 } },
    functionMocks: mocksFac1,
  },
  {
    label: '1c. DENY: admin no puede marcar pedidos/ped-fac-1 como facturado directamente',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: PEDIDO_1_PATH, method: 'update', time: TEST_TIME, resource: { data: pedido1Despues } },
    resource: { data: pedido1Antes },
    functionMocks: mocksFac1,
  },
  {
    label: '2a. DENY: admin no puede actualizar contadores/facturas directamente',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: CONTADOR_PATH, method: 'update', time: TEST_TIME, resource: { data: contador2 } },
    resource: { data: contador1 },
    functionMocks: mocksFac2,
  },
  {
    label: '2b. DENY: admin no puede crear ventas/FAC-0002 directamente',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: VENTA_2_PATH, method: 'create', time: TEST_TIME, resource: { data: venta2 } },
    functionMocks: mocksFac2,
  },
  {
    label: '2c. DENY: admin no puede marcar pedidos/ped-fac-2 como facturado directamente',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: PEDIDO_2_PATH, method: 'update', time: TEST_TIME, resource: { data: pedido2Despues } },
    resource: { data: pedido2Antes },
    functionMocks: mocksFac2,
  },
  {
    label: '3. ALLOW: facturación manual existente (ventas/1763123456789)',
    expectation: 'ALLOW',
    request: {
      auth: { uid: ADMIN_UID },
      path: VENTA_MANUAL_PATH,
      method: 'create',
      time: TEST_TIME,
      resource: { data: crearVentaFac('1763123456789') },
    },
  },
  {
    label: '4. DENY: pedido con accesorios pendientes (en_proceso)',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: PEDIDO_1_PATH, method: 'update', time: TEST_TIME, resource: { data: pedido1Despues } },
    resource: { data: crearPedidoBase({ id: PEDIDO_1_ID, estadoItem: 'en_proceso' }) },
    functionMocks: mocksFac1,
  },
  {
    label: '5. DENY: pedido ya facturado',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: PEDIDO_1_PATH, method: 'update', time: TEST_TIME, resource: { data: pedido1Despues } },
    resource: { data: crearPedidoBase({ id: PEDIDO_1_ID, facturado: true, ventaId: 'FAC-0001', facturaNumero: 'FAC-0001' }) },
    functionMocks: mocksFac1,
  },
  {
    label: '6. DENY: usuario no administrador intenta facturar',
    expectation: 'DENY',
    request: { auth: { uid: UNAUTHORIZED_UID }, path: PEDIDO_1_PATH, method: 'update', time: TEST_TIME, resource: { data: pedido1Despues } },
    resource: { data: pedido1Antes },
    functionMocks: mocksFac1,
  },
  {
    label: '7. DENY: doble facturación / sobrescritura de ventas/FAC-0001',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: VENTA_1_PATH, method: 'create', time: TEST_TIME, resource: { data: venta1 } },
    functionMocks: [
      mockFn('exists', VENTA_1_PATH, { value: true }),
      ...mocksFac1.slice(1),
    ],
  },
  {
    label: '8. DENY: salto de consecutivo en contadores/facturas (1 -> 3)',
    expectation: 'DENY',
    request: {
      auth: { uid: ADMIN_UID },
      path: CONTADOR_PATH,
      method: 'update',
      time: TEST_TIME,
      resource: { data: { ultimoNumero: 3, ultimaVentaId: 'FAC-0003', ultimoPedidoId: PEDIDO_2_ID, updatedAt: TEST_TIME } },
    },
    resource: { data: contador1 },
    functionMocks: mocksFac2,
  },
  {
    label: '9. DENY: venta FAC-0001 sin contador/pedido asociado',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: VENTA_1_PATH, method: 'create', time: TEST_TIME, resource: { data: venta1 } },
    functionMocks: [
      mockFn('exists', VENTA_1_PATH, { value: false }),
      mockFn('existsAfter', CONTADOR_PATH, { value: false }),
    ],
  },
  {
    label: '10. DENY: contador modificado aisladamente sin venta',
    expectation: 'DENY',
    request: { auth: { uid: ADMIN_UID }, path: CONTADOR_PATH, method: 'create', time: TEST_TIME, resource: { data: contador1 } },
    functionMocks: [
      mockFn('exists', VENTA_1_PATH, { value: false }),
      mockFn('existsAfter', VENTA_1_PATH, { value: false }),
    ],
  },
  {
    label: '11. DENY: importes manipulados en ventas/FAC-0001',
    expectation: 'DENY',
    request: {
      auth: { uid: ADMIN_UID },
      path: VENTA_1_PATH,
      method: 'create',
      time: TEST_TIME,
      resource: { data: { ...venta1, total: 100.0 } },
    },
    functionMocks: mocksFac1,
  },
  {
    label: '12. DENY: modificación de campos ajenos a la facturación en pedido',
    expectation: 'DENY',
    request: {
      auth: { uid: ADMIN_UID },
      path: PEDIDO_1_PATH,
      method: 'update',
      time: TEST_TIME,
      resource: { data: { ...pedido1Despues, costoEnvio: 0.0 } },
    },
    resource: { data: pedido1Antes },
    functionMocks: mocksFac1,
  },
  ...(() => {
    const pedido20Antes = {
      ...crearPedidoBase({ id: PEDIDO_20_ID, numeroPedido: 'PED-0020' }),
      items: crearItemsTerminados(20, 25),
      costoEnvio: 100,
      borradorFactura: {
        impuestoPorcentaje: 15,
        descuentoMayoristaActivo: false,
        descuentoPorcentaje: 0,
        costoEnvio: 100,
        subtotalEstimado: 500,
        totalEstimado: 675,
      },
    };
    const pedido20Despues = {
      ...pedido20Antes,
      facturado: true,
      ventaId: 'FAC-0003',
      facturaNumero: 'FAC-0003',
      fechaFacturacion: TEST_TIME,
      updatedAt: TEST_TIME,
    };
    const contador20 = {
      ultimoNumero: 3,
      ultimaVentaId: 'FAC-0003',
      ultimoPedidoId: PEDIDO_20_ID,
      updatedAt: TEST_TIME,
    };
    const venta20 = {
      ...crearVentaFac('FAC-0003'),
      subtotal: 500.0,
      impuesto: 75.0,
      total: 675.0,
      envio: 100.0,
      descuentoMayoristaActivo: false,
      descuentoPorcentaje: 0.0,
      descuentoMonto: 0.0,
    };
    const mocksFac20 = [
      mockFn('exists', VENTA_20_PATH, { value: false }),
      mockFn('existsAfter', VENTA_20_PATH, { value: true }),
      mockFn('exists', PEDIDO_20_PATH, { value: true }),
      mockFn('existsAfter', PEDIDO_20_PATH, { value: true }),
      mockFn('get', PEDIDO_20_PATH, { value: { data: pedido20Antes } }),
      mockFn('getAfter', PEDIDO_20_PATH, { value: { data: pedido20Despues } }),
      mockFn('existsAfter', CONTADOR_PATH, { value: true }),
      mockFn('getAfter', CONTADOR_PATH, { value: { data: contador20 } }),
    ];

    const pedido21Antes = {
      ...crearPedidoBase({ id: PEDIDO_21_ID, numeroPedido: 'PED-0021' }),
      items: crearItemsTerminados(21, 25),
      costoEnvio: 100,
      borradorFactura: {
        impuestoPorcentaje: 15,
        descuentoMayoristaActivo: false,
        descuentoPorcentaje: 0,
        costoEnvio: 100,
        subtotalEstimado: 525,
        totalEstimado: 703.75,
      },
    };
    const pedido21Despues = {
      ...pedido21Antes,
      facturado: true,
      ventaId: 'FAC-0004',
      facturaNumero: 'FAC-0004',
      fechaFacturacion: TEST_TIME,
      updatedAt: TEST_TIME,
    };
    const contador21 = {
      ultimoNumero: 4,
      ultimaVentaId: 'FAC-0004',
      ultimoPedidoId: PEDIDO_21_ID,
      updatedAt: TEST_TIME,
    };
    const venta21 = {
      ...crearVentaFac('FAC-0004'),
      subtotal: 525.0,
      impuesto: 78.75,
      total: 703.75,
      envio: 100.0,
      descuentoMayoristaActivo: false,
      descuentoPorcentaje: 0.0,
      descuentoMonto: 0.0,
    };
    const mocksFac21 = [
      mockFn('exists', VENTA_21_PATH, { value: false }),
      mockFn('existsAfter', VENTA_21_PATH, { value: true }),
      mockFn('exists', PEDIDO_21_PATH, { value: true }),
      mockFn('existsAfter', PEDIDO_21_PATH, { value: true }),
      mockFn('get', PEDIDO_21_PATH, { value: { data: pedido21Antes } }),
      mockFn('getAfter', PEDIDO_21_PATH, { value: { data: pedido21Despues } }),
      mockFn('existsAfter', CONTADOR_PATH, { value: true }),
      mockFn('getAfter', CONTADOR_PATH, { value: { data: contador21 } }),
    ];

    return [
      {
        label: '13. DENY: admin no puede crear ventas/FAC-0003 directamente (20 accesorios)',
        expectation: 'DENY',
        request: { auth: { uid: ADMIN_UID }, path: VENTA_20_PATH, method: 'create', time: TEST_TIME, resource: { data: venta20 } },
        functionMocks: mocksFac20,
      },
      {
        label: '14. DENY: omitir el accesorio 20 (índice 19) del subtotal',
        expectation: 'DENY',
        request: {
          auth: { uid: ADMIN_UID },
          path: VENTA_20_PATH,
          method: 'create',
          time: TEST_TIME,
          resource: {
            data: {
              ...venta20,
              subtotal: 475.0,
              impuesto: 71.25,
              total: 646.25,
            },
          },
        },
        functionMocks: mocksFac20,
      },
      {
        label: '15. DENY: facturar pedido con 21 accesorios (excede límite de 20)',
        expectation: 'DENY',
        request: { auth: { uid: ADMIN_UID }, path: VENTA_21_PATH, method: 'create', time: TEST_TIME, resource: { data: venta21 } },
        functionMocks: mocksFac21,
      },
      {
        label: '16. ALLOW: admin puede leer factura FAC-0001',
        expectation: 'ALLOW',
        request: { auth: { uid: ADMIN_UID }, path: VENTA_1_PATH, method: 'get', time: TEST_TIME },
        resource: { data: venta1 },
      },
      {
        label: '17. ALLOW: admin puede leer contadores/facturas',
        expectation: 'ALLOW',
        request: { auth: { uid: ADMIN_UID }, path: CONTADOR_PATH, method: 'get', time: TEST_TIME },
        resource: { data: contador1 },
      },
      {
        label: '18. DENY: usuario no admin no puede leer factura FAC-0001',
        expectation: 'DENY',
        request: { auth: { uid: UNAUTHORIZED_UID }, path: VENTA_1_PATH, method: 'get', time: TEST_TIME },
        resource: { data: venta1 },
      },
      {
        label: '19. ALLOW: admin puede actualizar venta manual existente',
        expectation: 'ALLOW',
        request: {
          auth: { uid: ADMIN_UID },
          path: VENTA_MANUAL_PATH,
          method: 'update',
          time: TEST_TIME,
          resource: { data: { ...crearVentaFac('1763123456789'), total: 600.0 } },
        },
        resource: { data: crearVentaFac('1763123456789') },
      },
      {
        label: '20. ALLOW: admin puede eliminar venta manual existente',
        expectation: 'ALLOW',
        request: { auth: { uid: ADMIN_UID }, path: VENTA_MANUAL_PATH, method: 'delete', time: TEST_TIME },
        resource: { data: crearVentaFac('1763123456789') },
      },
      {
        label: '21. DENY: admin no puede modificar ni eliminar factura FAC-0001',
        expectation: 'DENY',
        request: { auth: { uid: ADMIN_UID }, path: VENTA_1_PATH, method: 'delete', time: TEST_TIME },
        resource: { data: venta1 },
      },
      {
        label: '22. ALLOW: admin sigue pudiendo actualizar estado de producción en pedido',
        expectation: 'ALLOW',
        request: {
          auth: { uid: ADMIN_UID },
          path: PEDIDO_1_PATH,
          method: 'update',
          time: TEST_TIME,
          resource: {
            data: {
              ...crearPedidoBase({ id: PEDIDO_1_ID, estadoItem: 'en_proceso' }),
              items: crearPedidoBase({ id: PEDIDO_1_ID, estadoItem: 'terminado' }).items,
              estadoProduccion: 'terminado',
              updatedAt: TEST_TIME,
            },
          },
        },
        resource: { data: crearPedidoBase({ id: PEDIDO_1_ID, estadoItem: 'en_proceso' }) },
      },
    ];
  })(),
];

async function ejecutarPruebas() {
  const rulesPath = path.resolve(import.meta.dirname, '..', 'firestore.rules');
  const localRules = fs.readFileSync(rulesPath, 'utf8');

  const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const accessToken = cfg?.tokens?.access_token;

  if (!accessToken) {
    console.error('No se encontró access_token en firebase-tools.json.');
    process.exitCode = 1;
    return;
  }

  const payload = {
    source: { files: [{ name: 'firestore.rules', content: localRules }] },
    testSuite: { testCases: cases.map(({ label: _l, ...tc }) => tc) },
  };

  const resp = await fetch(
    `https://firebaserules.googleapis.com/v1/projects/${PROJECT_ID}:test`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    },
  );

  if (!resp.ok) {
    const errText = await resp.text();
    console.error(`Error HTTP ${resp.status} en projects.test: ${errText}`);
    if (resp.status === 401) {
      console.error('Sugerencia: ejecuta "firebase projects:list --json | Out-Null" para refrescar el token OAuth.');
    }
    process.exitCode = 1;
    return;
  }

  const report = await resp.json();
  const issues = report.issues ?? [];
  const warnings = issues.filter((issue) => issue.severity === 'WARNING');
  const errors = issues.filter((issue) => issue.severity !== 'WARNING');

  if (warnings.length > 0) {
    console.warn('Advertencias en firestore.rules:', JSON.stringify(warnings, null, 2));
  }

  if (errors.length > 0) {
    console.error('Errores en firestore.rules:', JSON.stringify(errors, null, 2));
    process.exitCode = 1;
    return;
  }

  const results = report.testResults ?? [];
  let allPassed = results.length === cases.length;

  for (let i = 0; i < cases.length; i++) {
    const c = cases[i];
    const tr = results[i] ?? {};
    const ok = tr.state === 'SUCCESS';
    if (!ok) allPassed = false;

    if (ok) {
      console.log(`OK | ${c.label} | esperado=${c.expectation} | estado=${tr.state}`);
      continue;
    }

    console.log(`FAIL | ${c.label} | esperado=${c.expectation} | estado=${tr.state}`);
    if (tr.debugMessages?.length) {
      console.log(`  debugMessages: ${tr.debugMessages.join('; ')}`);
    }
    if (tr.errorPosition) {
      console.log(`  errorPosition: ${JSON.stringify(tr.errorPosition)}`);
    }
    if (tr.visitedExpressions?.length) {
      console.log(`  visitedExpressions: ${JSON.stringify(tr.visitedExpressions)}`);
    }
    console.log(`  testResult: ${JSON.stringify(tr)}`);
  }

  process.exitCode = allPassed ? 0 : 1;
}

await ejecutarPruebas();
