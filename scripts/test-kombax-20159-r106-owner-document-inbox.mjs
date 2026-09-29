import fs from 'node:fs';
import path from 'node:path';

const root=process.cwd();
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const migration=read('supabase/migrations/294_kombax_owner_document_inbox_r106.sql');
const edge=read('supabase/functions/kombax-owner-agents-r105/index.ts');
const repo=read('web/js/core/repositories.js');
const ui=read('web/js/modules/platform-admin.js');
const css=read('web/css/kombax-premium.css');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');

const checks=[
  ['tabla documental privada',migration.includes('kombax_owner_ai.documents')&&migration.includes('revoke all on kombax_owner_ai.documents')],
  ['bucket privado y limitado',migration.includes("values('kombax-owner-inbox','kombax-owner-inbox',false,10485760")],
  ['políticas Owner por usuario',migration.includes('kombax_owner_inbox_insert_r106')&&migration.includes("(storage.foldername(name))[1]=(select auth.uid())::text")],
  ['adjuntos limitados a tres',migration.includes('OWNER_AGENT_DOCUMENT_LIMIT')&&edge.includes('.slice(0,3)')],
  ['lectura de PDF y documentos',edge.includes("type:'input_file'")&&edge.includes('file_data:data')],
  ['lectura visual de imágenes',edge.includes("type:'input_image'")&&edge.includes("detail:'auto'")],
  ['archivos no persistidos en OpenAI',edge.includes('store:false')&&!edge.includes('/v1/files')],
  ['estado documental auditable',migration.includes('app_kombax_owner_agent_documents_finish_r106')],
  ['informe piloto como borrador',migration.includes('app_kombax_owner_pilot_report_from_turn_r106')&&edge.includes("action==='create_pilot_report'")],
  ['subida web restringida',repo.includes('ownerAgentDocumentUpload')&&repo.includes("file.size>10*1024*1024")],
  ['bandeja Owner visible',ui.includes('BANDEJA DOCUMENTAL')&&ui.includes('Documentos Owner ordenados')],
  ['acciones de un toque',ui.includes('data-owner-agent-prompt')&&ui.includes('form.requestSubmit()')],
  ['documento enviado al agente',ui.includes('data-owner-document-agent')&&ui.includes('document_ids:documentIds')],
  ['salida Owner visible',ui.includes('kx-owner-close-admin')&&ui.includes('backend.signOutPlatformAdmin()')],
  ['responsive documental',css.includes('.kx-owner-document-upload')&&css.includes('.kx-owner-session-bar')],
  ['build web incluye R106',/build:\s*201(?:59|6\d)/.test(config)],
  ['build Android incluye R106',/versionCode\s+201(?:59|6\d)/.test(gradle)]
];

let failed=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)failed++;}
if(failed){console.error(`R106: ${failed} comprobación(es) fallida(s).`);process.exit(1);}
console.log(`PASS R106 · ${checks.length} comprobaciones`);
