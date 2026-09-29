import fs from 'node:fs';
const read=file=>fs.readFileSync(file,'utf8');
const sql=read('supabase/migrations/295_kombax_owner_conversations_r107.sql');
const repo=read('web/js/core/repositories.js');
const ui=read('web/js/modules/platform-admin.js');
const css=read('web/css/kombax-premium.css');
const config=read('web/config.js');
const gradle=read('android/app/build.gradle');
const checks=[
 ['conversaciones privadas',sql.includes('kombax_owner_ai.conversations')&&sql.includes('revoke all on kombax_owner_ai.conversations')],
 ['operaciones guardar y archivar',sql.includes("p_operation in ('save','rename','archive','reopen')")],
 ['conversación aislada por Owner',sql.includes('owner_id=v_uid')&&sql.includes("status<>'archived'")],
 ['RPC de listado',sql.includes('app_kombax_owner_agent_conversations_r107')],
 ['repositorio de chats',repo.includes('ownerAgentConversations')&&repo.includes('ownerAgentConversation:')],
 ['ventana interna de chats',ui.includes('Conversaciones y análisis')&&ui.includes('data-owner-conversation-open')],
 ['crear guardar archivar',ui.includes('data-owner-conversation-new')&&ui.includes('data-owner-conversation-save')&&ui.includes('data-owner-conversation-archive')],
 ['acordeones Owner',ui.includes('bindOwnerSectionAccordions')&&css.includes('.kx-platform-section.is-collapsed')],
 ['directorio por letras',ui.includes('data-owner-profile-letters')&&ui.includes('data-letter=')],
 ['paginación diez',ui.includes('const perPage=10')&&ui.includes('data-owner-profile-pagination')],
 ['histograma',ui.includes('kx-owner-histogram')&&css.includes('.kx-owner-histogram')],
 ['salida administración',ui.includes('kx-owner-close-admin')&&ui.includes('signOutPlatformAdmin')],
 ['build web',config.includes("version: '2.0.0-rc.13-r107-owner-workspace'")&&config.includes('build: 20160')],
 ['build Android',gradle.includes('versionCode 20160')&&gradle.includes("versionName '2.0.0-rc.13-r107-owner-workspace'")]
];
let failed=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} ${name}`);if(!ok)failed++;}if(failed)process.exit(1);console.log(`PASS R107 · ${checks.length} comprobaciones`);
