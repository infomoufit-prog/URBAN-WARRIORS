import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const root=resolve(new URL('..',import.meta.url).pathname);
const read=p=>readFileSync(resolve(root,p),'utf8');
const must=(ok,msg)=>{if(!ok)throw new Error(`20040: ${msg}`)};
const sqlPath='supabase/migrations/065_kombax_social_affiliation_contact_20040.sql';
must(existsSync(resolve(root,sqlPath)),'falta migración 065');
const sql=read(sqlPath);
const hardeningPath='supabase/migrations/066_kombax_contact_index_hardening_20040.sql';
must(existsSync(resolve(root,hardeningPath)),'falta migración 066 de índices de contacto');
const hardening=read(hardeningPath);
const repos=read('web/js/core/repositories.js');
const social=read('web/js/modules/kombax-social.js');
const profile=read('web/js/modules/public-profile.js');
const css=read('web/css/kombax-premium.css');

// Contrato legal: la interfaz y el backend ya no pueden declarar que no existe mensajería.
must(/'1\.2\.0'/.test(sql)&&/Contacto KOMBAX/.test(sql),'falta actualización de Normas Social 1.2');
must(/máximo 20 mensajes totales/.test(sql)&&/menor de 18 años/.test(sql),'Normas 1.2 no reflejan límites/protección de menores');
must((repos.includes('app_kombax_identity_mutate_v094')||repos.includes('app_kombax_identity_mutate_v065'))&&(repos.includes('app_kombax_social_mutate_v067')||repos.includes('app_kombax_social_mutate_v065'))&&repos.includes('app_kombax_social_estado_v065'),'frontend no usa gateway de identidad 065 o wrapper endurecido posterior + estado legal 065');

// Afiliación: fuente canónica y control explícito.
must(/add column if not exists afiliacion_visible boolean not null default true/i.test(sql),'falta control de visibilidad de afiliación');
must(/app_kombax_social_afiliacion_v065/i.test(sql),'falta helper de afiliación');
must(/s\.estado='activo'/i.test(sql),'la afiliación no exige socio activo');
must(/i\.estado='activa'/i.test(sql),'la afiliación no exige identidad activa');
must(/'verificada',true/i.test(sql),'la afiliación no se marca como verificada');
must(/club_social_id/i.test(sql),'falta enlace a identidad Social del club');
must(/kombax\.social\.affiliation\.visibility/i.test(sql),'falta mutación de visibilidad');
must(/kombax\.social\.affiliation\.share/i.test(sql),'falta publicación canónica de afiliación');

// Contacto KOMBAX: solo texto, límite duro y seguridad por participantes.
must(/create table if not exists public\.kombax_social_contacto_mensajes/i.test(sql),'falta tabla de mensajes');
must(/ordinal smallint not null check\(ordinal between 1 and 20\)/i.test(sql),'falta ordinal máximo 20');
must(/texto text not null check\(char_length\(btrim\(texto\)\) between 1 and 500\)/i.test(sql),'falta límite de texto');
const msgTable=(sql.match(/create table if not exists public\.kombax_social_contacto_mensajes\s*\(([\s\S]*?)\n\);/i)||[])[1]||'';
must(msgTable.length>0,'no se localiza la definición de tabla de mensajes');
must(!/\b(storage_path|media_id|archivo|mime_type|url)\b/i.test(msgTable),'la tabla de mensajes introduce multimedia/archivos');
must(/alter table public\.kombax_social_contacto_mensajes enable row level security/i.test(sql),'RLS no activada en mensajes');
must(/revoke all on public\.kombax_social_contacto_mensajes from public,anon,authenticated/i.test(sql),'tabla de mensajes expuesta directamente');
must(/app_kombax_contact_can_access_v065/i.test(sql),'falta helper de autorización de hilo');
must(!/app_kombax_contact_can_access_v065[\s\S]{0,700}app_kombax_es_moderador_v041/i.test(sql),'moderación no debe tener lectura global implícita de mensajes privados');
must(/app_kombax_contact_pair_blocked_v065/i.test(sql),'falta bloqueo bilateral del contacto');
must(/app_kombax_social_puede_actuar_v051\(c\.remitente_social_id\)[\s\S]*app_kombax_social_puede_actuar_v051\(c\.destinatario_social_id\)/i.test(sql),'acceso al hilo no exige participante');
must(/KOMBAX_CONTACT_MESSAGE_LIMIT_20/i.test(sql),'falta enforcement del límite 20');
must(/if v_message\.ordinal>=v_limit then[\s\S]*estado='cerrada'/i.test(sql),'el hilo no se cierra al agotar el límite');
must(/uq_kombax_contact_pair_open_v065/i.test(sql),'falta impedir dos hilos abiertos por pareja');
must(/app_kombax_contact_seed_message_v065/i.test(sql),'falta compatibilidad del primer mensaje');
must(/insert into public\.kombax_social_contacto_mensajes[\s\S]*select c\.id,c\.remitente_social_id,c\.creado_por,1,c\.mensaje/i.test(sql),'contactos históricos no se convierten a mensaje 1');

// Hardening de rendimiento: todas las FK locales del agregado Contacto deben quedar cubiertas.
for(const idx of [
  'idx_kombax_contact_messages_author_v066',
  'idx_kombax_contact_messages_created_by_v066',
  'idx_kombax_social_contactos_cerrado_por_v066',
  'idx_kombax_social_contactos_creado_por_v066',
  'idx_kombax_social_contactos_respondido_por_v066'
]) must(hardening.includes(idx),`falta índice de hardening ${idx}`);

// Contratos frontend nuevos.
must(repos.includes("app_kombax_social_feed_v065"),'frontend no usa feed 065');
must(repos.includes("app_kombax_social_directorio_v065"),'frontend no usa directorio 065');
must(repos.includes("app_kombax_perfil_publico_v065")||repos.includes("app_kombax_perfil_publico_v068"),'frontend no usa perfil público 065 o wrapper posterior compatible');
must((repos.includes("app_kombax_contactos_v067")||repos.includes("app_kombax_contactos_v065")),'frontend no usa bandeja de contactos 065');
must((repos.includes("app_kombax_contact_mensajes_v067")||repos.includes("app_kombax_contact_mensajes_v065")),'frontend no lee mensajes 065');
must((repos.includes("app_kombax_social_network_mutate_v067")||repos.includes("app_kombax_social_network_mutate_v065")),'frontend no usa mutación de red 065');

// UX profesional y separación de identidad.
must(social.includes('Contacto KOMBAX'),'falta etiqueta Contacto KOMBAX');
must(social.includes('20 mensajes totales'),'falta explicación del límite 20');
must(social.includes('Solo texto'),'falta señalización solo texto');
must(social.includes('data-social-affiliation-club'),'feed/directorio no enlazan afiliación al club');
must(social.includes('affiliationChip'),'falta chip de afiliación verificada');
must(profile.includes('Afiliación verificada')||profile.includes('Afiliación confirmada'),'perfil público no muestra afiliación confirmada/verificada');
must(profile.includes('kx-public-share-affiliation'),'falta acción compartir afiliación');
must(profile.includes('afiliacion_visible'),'falta control de visibilidad en edición');
must(profile.includes('setAffiliationVisibility'),'edición no persiste visibilidad');
must(profile.includes('shareAffiliation'),'perfil no publica afiliación canónica');
must(css.includes('.kx-contact-message-list')&&css.includes('.kx-affiliation-chip'),'faltan estilos de Contacto/Afiliación');

// Protección de menores: se conserva la regla existente de 18+ para contacto personal.
must(social.includes('menor de 18 años')||social.includes('menores de 18 años'),'la UI no informa protección de menores');
must(/KOMBAX_CONTACT_NOT_AVAILABLE_18_PLUS/.test(sql),'backend no conserva barrera de contacto 18+');

console.log('KOMBAX BUILD 20040 SOCIAL AFFILIATION + CONTACT: PASS');
