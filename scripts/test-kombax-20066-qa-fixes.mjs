import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const app=read('web/js/app.js');
const backend=read('web/js/core/backend.js');
const gateway=read('web/js/modules/gateway.js');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const {humanError}=await import('../web/js/core/utils.js');

const currentBuild=Number(config.match(/build:\s*(\d+)/)?.[1]);
assert.ok(currentBuild>=20066);
assert.equal(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),currentBuild);
assert.match(app,/if\(type==='invite'\)openInvitationChoice\(\)/);
assert.doesNotMatch(app,/\bopenInvitation\(\)/);
assert.match(gateway,/required:!application/);
assert.match(gateway,/Borrador guardado\. Revisa los requisitos antes de reenviar\./);
assert.match(backend,/GLOBAL RPC \$\{name\}[\s\S]{0,500}throw error;/);
assert.equal(humanError(new Error('KOMBAX_VERIFICATION_DOCUMENT_REQUIRED')),'Adjunta un documento acreditativo antes de enviar la solicitud.');
assert.equal(humanError(new Error('KOMBAX_APPLICATION_FIELDS_REQUIRED:ubicacion,email_oficial')),'Revisa los campos obligatorios antes de enviar: ubicación, correo oficial.');

console.log('KOMBAX 20066 QA registration + profile submission fixes: PASS');
