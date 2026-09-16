import fs from 'node:fs';
import path from 'node:path';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const events=read('web/js/modules/kombax-events.js');
const repos=read('web/js/core/repositories.js');
const css=read('web/css/kombax-events.css');
const migration=read('supabase/migrations/181_kombax_events_creator_participant_update_20101_r14.sql');
const index=read('web/index.html'),sw=read('web/service-worker.js');
const checks=[
 ['R14 builder exists',events.includes('async function openEventBuilder')&&(/EVENT CREATOR · R(?:14|1[5-9]|2\d)/.test(events))],
 ['creator continues into builder after first save',events.includes("returnToBuilder||!event?openEventBuilder(saved.id):openEvent(saved.id")],
 ['builder integrates six operational steps',['Ficha e información','Portada y banner','Organización','Participantes y fotos','Fight Card y horarios','Álbum y multimedia'].every(x=>events.includes(x))],
 ['manager album nav remains visible when empty',events.includes('hasMedia||canManage')&&events.includes('canManage:event.can_manage')&&events.includes('Álbum · ${Number(mediaCount)||0}')],
 ['empty manager album has direct upload CTA',events.includes('data-kx-album-manage')&&events.includes('Subir fotos o vídeos')&&events.includes('El público no verá esta sección hasta que publiques contenido.')],
 ['participant photo replacement UI exists',events.includes('function openParticipantEditor')&&events.includes('Reemplazar foto pública')&&events.includes('Editar ficha / foto')],
 ['participant update repository uses v181',repos.includes("app_kombax_eventos_mutate_v181")&&repos.includes("event.participant.update")],
 ['participant update migration preserves workspace management',migration.includes('app_kombax_evento_contexto_gestion_v171')&&migration.includes('EVENT_WORKSPACE_MANAGEMENT_FORBIDDEN')&&migration.includes("p_operation<>'event.participant.update'" )],
 ['fight card manager exists',events.includes('async function openFightCardManager')&&events.includes('Añadir combate')&&events.includes('Editar / horario')],
 ['album upload can link to fight',events.includes('kx-media-fight-link')&&events.includes("combate_id:wrap.querySelector('#kx-media-fight-link')?.value||null")],
 ['album upload can link to KOMBAX competitor',events.includes('kx-media-competitor-link')&&events.includes("competidor_social_profile_id:wrap.querySelector('#kx-media-competitor-link')?.value||null")],
 ['album retains valid photo/video quota after later expansion',(events.includes('/ 30 fotos')||events.includes('/ 15 fotos'))&&events.includes('/ 5 vídeos')],
 ['R14 responsive builder CSS exists',css.includes('.kx-event-builder-step')&&css.includes('.kx-fight-manager-list')&&css.includes('.kx-media-association-grid')&&css.includes('@media(max-width:430px)')],
 ['cache bust R14',revisionAtLeast(index,14)&&revisionAtLeast(sw,14,'media-r')],
 ['Urban Warriors assets preserved',fs.existsSync(path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub/poster.webp'))],
 ['signing remains externally configured',fs.existsSync(path.join(root,'android/keystore.properties.example'))&&!fs.existsSync(path.join(root,'LOCAL_RELEASE_SIGNING/kombax-release.jks'))]
];
let bad=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);console.log('OK KOMBAX 20.101 R14 Event Creator Complete');
