import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const files={
  support:read('web/js/modules/support-privacy.js'),
  admin:read('web/js/modules/admin.js'),
  gateway:read('web/js/modules/gateway.js'),
  repo:read('web/js/core/repositories.js'),
  events:read('web/js/modules/kombax-events.js'),
  app:read('web/js/app.js'),
  sql:read('supabase/migrations/194_kombax_authorized_support_privacy_20101_r26.sql'),
  index:read('web/index.html'),
  sw:read('web/service-worker.js')
};
const checks=[];const ok=(name,cond)=>checks.push([name,Boolean(cond)]);
ok('support email canonical',files.support.includes("SUPPORT_EMAIL='soporte@kombax.es'"));
ok('club settings exposes privacy support',files.admin.includes("subjectType:'club'")&&files.admin.includes('Privacidad y soporte del club'));
ok('personal profile exposes account privacy support',files.admin.includes("subjectType:'account'")&&files.admin.includes('Privacidad y soporte de mi cuenta'));
ok('direct profiles expose privacy support',files.gateway.includes('data-kx-profile-support')&&files.gateway.includes("subjectType:'direct_profile'"));
ok('managed clubs expose privacy support',files.gateway.includes('data-kx-club-support'));
ok('support grant is temporal',files.sql.includes('expires_at timestamptz not null')&&files.sql.includes('duration_minutes'));
ok('support grant is scoped',files.sql.includes("'support.read','support.write','finance.read','documents.read','minors.read'"));
ok('support code stored hashed',files.sql.includes('code_hash text not null unique')&&(files.sql.includes("digest(v_code,'sha256')")||files.sql.includes("extensions.digest(v_code,'sha256')")));
ok('plaintext code returned once by create path',files.sql.includes("jsonb_build_object('id',v_row.id,'code',v_code"));
ok('support grants are revocable',files.sql.includes("support.authorization.revoke")&&files.sql.includes("status='revoked'"));
ok('support lifecycle audited',files.sql.includes('kombax_support_access_audit_v194')&&files.sql.includes('support.authorization.created')&&files.sql.includes('support.authorization.claimed'));
ok('AI claim restricted to service role',files.sql.includes("v_role <> 'service_role'")&&files.sql.includes('SUPPORT_SERVICE_ROLE_REQUIRED'));
ok('AI authorization validation checks required scope',files.sql.includes('SUPPORT_SCOPE_FORBIDDEN')&&files.sql.includes('p_required_scope'));
ok('club authorization requires direction or coordination',files.sql.includes("mc.rol='direccion' or mc.coordinacion=true"));
ok('direct profile authorization requires owner manager',files.sql.includes("pg.rol in ('owner','admin')"));
ok('authenticated cannot read support tables directly',files.sql.includes('revoke all on public.kombax_support_authorizations_v194 from anon, authenticated'));
ok('Owner support mode remains present and independent',files.app.includes('enterOwnerSupportMode')&&files.repo.includes('entitySessionStart')&&files.repo.includes('supportAudit'));
ok('user copy discloses privileged admin exception',files.support.includes('Administrador General de KOMBAX conserva una vía privilegiada independiente'));
ok('Events preserves filters across route re-entry',!files.events.includes('export async function renderKombaxEvents(){\n  resetEventFilters();'));
ok('Events restores prior scroll position',files.events.includes('eventsLastScrollY')&&files.events.includes('restoreEventsScroll'));
ok('Events renders cached discovery before revalidation',files.events.includes("if(cached.length){renderList();restoreEventsScroll();}"));
ok('Events still refreshes server discovery',files.events.includes('await loadDiscovery({append:false})'));
ok('R26+ web cache bust',files.index.includes('20101r26')||files.index.includes('20101r27'));
ok('R26+ service worker cache bust',files.sw.includes('media-r26')||files.sw.includes('media-r27'));
let failed=0;for(const [name,pass] of checks){console.log(`${pass?'PASS':'FAIL'} · ${name}`);if(!pass)failed++;}
console.log(`R26 ${checks.length-failed}/${checks.length}`);process.exit(failed?1:0);
