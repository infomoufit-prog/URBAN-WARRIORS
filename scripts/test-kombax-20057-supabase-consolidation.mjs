import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);
const read=p=>readFile(new URL(p,root),'utf8');
const [mig,rb,repo,cfg,sw,index,gradle]=await Promise.all([
  read('supabase/migrations/100_kombax_supabase_consolidation_20057.sql'),
  read('supabase/rollbacks/100_kombax_supabase_consolidation_20057_rollback.sql'),
  read('web/js/core/repositories.js'),read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('android/app/build.gradle')
]);
const ok=(v,m)=>{if(!v)throw new Error(m);console.log('OK '+m)};
const n=s=>s.toLowerCase().replace(/\s+/g,' ');
const m=n(mig), r=n(rb);
for(const fn of [
 'app_kombax_social_mutate_v083(text,jsonb,uuid)',
 'app_kombax_identity_mutate_v065(text,jsonb,uuid)',
 'app_kombax_social_feed_v083(timestamptz,uuid,integer)',
 'app_kombax_social_media_v053(uuid)',
 'app_kombax_perfil_publico_v083(uuid)'
]) ok(m.includes(`revoke execute on function public.${fn} from public, anon, authenticated`),`cierra RPC superseded: ${fn}`);
ok(repo.includes("globalWriteRpc('app_kombax_social_mutate_v099'")&&repo.includes("globalWriteRpc('app_kombax_identity_mutate_v094'"),'frontend usa mutaciones vigentes v099/v094');
ok(repo.includes("globalReadRpc('app_kombax_social_feed_v085'")&&repo.includes("globalReadRpc('app_kombax_perfil_publico_v094'")&&repo.includes("globalReadRpc('app_kombax_social_media_v085'"),'frontend usa lecturas Social vigentes');
ok(m.includes('alter policy perfil_propio on public.perfiles to authenticated')&&m.includes('alter policy socios_lectura on public.socios to authenticated')&&m.includes('alter policy notificaciones_propias on public.notificaciones to authenticated'),'policies históricas no públicas se estrechan a authenticated');
ok(m.includes('select auth.uid()')&&m.includes('select auth.jwt()'),'RLS usa initplan estable para Auth');
ok(!/using \([^;]*=auth\.uid\(\)/.test(m),'migración 100 no reintroduce auth.uid directo en USING nuevos');
ok(m.includes('drop index if exists public.idx_material_pedidos_club_validacion'),'retira índice material_pedidos duplicado');
for(const idx of ['idx_socios_perfil_fk_v100','idx_dispositivos_push_perfil_fk_v100','idx_kombax_social_posts_social_media_fk_v100','idx_asistencias_club_socio_fk_v100','idx_material_pedidos_club_socio_fk_v100']) ok(m.includes(`create index if not exists ${idx}`),`índice FK consolidación: ${idx}`);
ok(r.includes('grant execute on function public.app_kombax_social_mutate_v083')&&r.includes('alter policy perfil_propio on public.perfiles using (id=auth.uid())')&&r.includes('create index if not exists idx_material_pedidos_club_validacion'),'rollback restaura RPC/policies/índice previo');
ok(r.includes('drop index if exists public.idx_socios_perfil_fk_v100')&&r.includes("notify pgrst,'reload schema'"),'rollback elimina índices v100 y recarga schema');
ok(cfg.includes('build: 20057')&&sw.includes('rc13-20057')&&index.includes('v=20057')&&gradle.includes('versionCode 20057'),'web/PWA/Android marcan build 20057');
console.log('KOMBAX BUILD 20057 · Supabase consolidation: PASS');
