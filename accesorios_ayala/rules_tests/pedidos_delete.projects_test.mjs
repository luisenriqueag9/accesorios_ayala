import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const PROJECT_ID = 'accesorios-ayala';
const ADMIN_UID_1 = 'sK72fiKvY0crBfUzpP4TuqnHhBE3';
const ADMIN_UID_2 = 'PefdVcw7gRayt1hgCUAZt7ejgYO2';
const UNAUTHORIZED_UID = 'usuario_no_autorizado_999';
const DOC_PATH = '/databases/(default)/documents/pedidos/ped-delete-test';

const pedidoBase = {
  id: 'ped-delete-test',
  numeroPedido: 'PED-0999',
  clienteId: 'cli-test',
  clienteNombre: 'Cliente Prueba',
  items: [
    {
      itemId: 'item-1',
      productoId: 'prod-1',
      nombre: 'Pulsera Prueba',
      cantidad: 1,
      precioUnitario: 200,
      notaPersonalizacion: '',
      estadoElaboracion: 'recibido',
    },
  ],
  estadoProduccion: 'recibido',
  estadoEnvio: 'pendiente',
  costoEnvio: 100,
  facturado: false,
  ventaId: null,
  facturaNumero: null,
};

const pedidoAntiguoSinOpcionales = {
  id: 'ped-delete-test',
  numeroPedido: 'PED-0998',
  clienteId: 'cli-test',
  clienteNombre: 'Cliente Antiguo',
  items: pedidoBase.items,
  estadoProduccion: 'recibido',
};

const cases = [
  {
    label: '1. ALLOW: admin elimina pedido sin facturar',
    expectation: 'ALLOW',
    auth: { uid: ADMIN_UID_1 },
    resourceData: pedidoBase,
  },
  {
    label: '2. ALLOW: admin elimina pedido antiguo sin campos opcionales',
    expectation: 'ALLOW',
    auth: { uid: ADMIN_UID_2 },
    resourceData: pedidoAntiguoSinOpcionales,
  },
  {
    label: '3. DENY: usuario no administrador intenta eliminar pedido',
    expectation: 'DENY',
    auth: { uid: UNAUTHORIZED_UID },
    resourceData: pedidoBase,
  },
  {
    label: '4. DENY: admin intenta eliminar pedido con facturado: true',
    expectation: 'DENY',
    auth: { uid: ADMIN_UID_1 },
    resourceData: { ...pedidoBase, facturado: true },
  },
  {
    label: '5. DENY: admin intenta eliminar pedido con ventaId asignado',
    expectation: 'DENY',
    auth: { uid: ADMIN_UID_1 },
    resourceData: { ...pedidoBase, ventaId: 'venta-123' },
  },
  {
    label: '6. DENY: admin intenta eliminar pedido con facturaNumero asignado',
    expectation: 'DENY',
    auth: { uid: ADMIN_UID_1 },
    resourceData: { ...pedidoBase, facturaNumero: 'FAC-0001' },
  },
  {
    label: '7. DENY: usuario no autenticado intenta eliminar pedido',
    expectation: 'DENY',
    auth: null,
    resourceData: pedidoBase,
  },
];

const rulesPath = path.resolve(import.meta.dirname, '..', 'firestore.rules');
const localRules = fs.readFileSync(rulesPath, 'utf8');

const cfgPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const accessToken = cfg?.tokens?.access_token;

if (!accessToken) {
  console.error('No se encontró access_token en firebase-tools.json.');
  process.exit(1);
}

const payload = {
  source: {
    files: [{ name: 'firestore.rules', content: localRules }],
  },
  testSuite: {
    testCases: cases.map((c) => ({
      expectation: c.expectation,
      request: {
        ...(c.auth ? { auth: c.auth } : {}),
        path: DOC_PATH,
        method: 'delete',
      },
      resource: { data: c.resourceData },
    })),
  },
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
  process.exit(1);
}

const report = await resp.json();
if (report.issues?.length) {
  console.error('Issues en firestore.rules:', JSON.stringify(report.issues, null, 2));
  process.exit(1);
}

const results = report.testResults ?? [];
let allPassed = results.length === cases.length;

for (let i = 0; i < cases.length; i++) {
  const c = cases[i];
  const tr = results[i] ?? {};
  const ok = tr.state === 'SUCCESS';
  if (!ok) allPassed = false;
  console.log(`${ok ? 'OK' : 'FAIL'} | ${c.label} | esperado=${c.expectation} | estado=${tr.state}`);
}

process.exit(allPassed ? 0 : 1);
