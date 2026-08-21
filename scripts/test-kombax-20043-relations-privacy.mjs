import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
const root=resolve(new URL('..',import.meta.url).pathname);
const read=p=>readFileSync(resolve(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(`20043: ${msg}`)};
const migration='supabase/migrations/068_kombax_relations_privacy_20043.sql';
must(existsSync(resolve(root,migration)),'falta migración 068');
const sql=read(migration),repos=read('web/js/core/repositories.js'),social=read('web/js/modules/kombax-social.js'),publicProfile=read('web/js/modules/public-profile.js'),config=read('web/config.js'),index=read('web/index.html'),sw=read('web/service-worker.js'),gradle=read('android/app/build.gradle');

const build=Number(config.match(/build:\s*(\d+)/)?.[1]||0);
const versionCode=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
must(build>=20043,'config es anterior a 20043');
must(versionCode>=20043,'Android versionCode es anterior a 20043');
must(index.includes(`v=${build}`),'cache-busting no coincide con build');
must(sw.includes(String(build)),'service worker no coincide con build');

// Backend: lectura privada de relaciones y cierre de endpoints históricos.
must(sql.includes('app_kombax_relaciones_v068'),'falta RPC privada v068');
must(sql.includes('app_kombax_social_puede_actuar_v051(p_social_id)'),'la lista privada no comprueba control de identidad');
must(sql.includes("raise exception 'KOMBAX_RELATIONS_PRIVATE'"),'falta rechazo explícito de identidad ajena');
must(sql.includes("return v - 'relations'"),'perfil público v068 no elimina la red de relaciones');
for(const fn of ['app_kombax_relaciones_v045(uuid)','app_kombax_perfil_publico_v052(uuid)','app_kombax_perfil_publico_v053(uuid)','app_kombax_perfil_publico_v065(uuid)']){
  must(sql.includes(`revoke execute on function public.${fn} from authenticated`),`RPC histórico sigue expuesto: ${fn}`);
}
must(/revoke all on function public\.app_kombax_relaciones_v068\(uuid\) from public,anon/.test(sql),'v068 relations no cierra anon/public');
must(/revoke all on function public\.app_kombax_perfil_publico_v068\(uuid\) from public,anon/.test(sql),'v068 perfil no cierra anon/public');

// Frontend: no lista ni contador de relaciones en perfil público.
must(!publicProfile.includes('Relaciones verificadas'),'perfil público sigue mostrando sección Relaciones');
must(!publicProfile.includes('relations(p)'),'perfil público sigue renderizando relaciones');
must(!publicProfile.includes('Sin relaciones visibles'),'perfil público revela existencia/ausencia de relaciones');
must(repos.includes("app_kombax_perfil_publico_v068"),'frontend no usa perfil público privado v068');
must(repos.includes("app_kombax_relaciones_v068"),'Mis relaciones no usa RPC privada v068');

// UX: la persona sí conserva un espacio privado para gestionar su red.
must(social.includes("pageHeader('Mi red','Área privada."),'Mi red no se presenta como área privada');
must(social.includes('Ni tu red ni su tamaño se muestran públicamente.'),'solicitud no explica privacidad');
must(social.includes('Mi red es privada, requiere consentimiento'),'confirmación no explica privacidad');

// No introducir popularidad social pública en cards/feed/perfil.
const publicSurface=publicProfile+social.slice(0,social.indexOf('async function renderRelations'));
must(!/\b(relaciones_count|relation_count|numero_relaciones|número de relaciones)\b/i.test(publicSurface),'se introdujo contador público de relaciones');

console.log('KOMBAX BUILD 20043 RELATIONS PRIVACY: PASS');
