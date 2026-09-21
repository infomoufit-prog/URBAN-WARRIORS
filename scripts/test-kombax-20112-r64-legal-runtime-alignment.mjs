import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root=process.cwd();
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const backend=read('web/js/core/backend.js');
const gate=read('web/js/modules/platform-legal.js');

assert.match(backend,/const active=await platformLegalStatus\(\)/,'La aceptación debe consultar primero el contrato legal activo del backend.');
assert.match(backend,/active\?\.terms_version\|\|PLATFORM_TERMS_VERSION/,'La versión de Condiciones debe proceder del backend con fallback local.');
assert.match(backend,/active\?\.privacy_version\|\|PLATFORM_PRIVACY_VERSION/,'La versión de Privacidad debe proceder del backend con fallback local.');
assert.match(gate,/platform_legal\?\.terms_version/,'La interfaz debe mostrar la versión de Condiciones realmente exigida.');
assert.match(gate,/platform_legal\?\.privacy_version/,'La interfaz debe mostrar la versión de Privacidad realmente exigida.');
console.log('KOMBAX R64 legal runtime alignment: PASS (5/5)');
