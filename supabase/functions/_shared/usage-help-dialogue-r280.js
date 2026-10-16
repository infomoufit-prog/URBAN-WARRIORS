import {selectHelpTopics,helpSafeHistory,normalizeHelpText,helpIsFollowup as baseFollowup} from './usage-help-knowledge.js';

// Server-only interpretation. Audience and permission checks remain in the
// shared selector; neither a synonym nor conversation history grants access.
const synonyms={mensualidad:'cuota',mensualidades:'cuotas',abono:'pago',abonos:'pagos',fraccionado:'parcial',fraccionar:'parcial',escaparate:'showcase',escaparates:'showcase',pabellon:'evento',turnos:'grupos',turno:'grupo',inscribir:'inscripciones',matricular:'inscripciones',matricula:'inscripciones',diplomas:'acreditaciones',diploma:'acreditacion',certificados:'acreditaciones',cinturones:'grados',cinturon:'grado',renovar:'renovacion'};
function retrievalQuery(message){return normalizeHelpText(String(message).slice(0,1500)).split(' ').map(word=>synonyms[word]||word).join(' ');}
function ranked(guides,message,context,limit){
 const rows=selectHelpTopics(guides,retrievalQuery(message),context,guides.length);
 const seen=new Set();return rows.filter(row=>{if(seen.has(row.id))return false;seen.add(row.id);return true;}).slice(0,limit);
}
export function helpIsFollowup(message=''){
 const q=normalizeHelpText(message);
 return baseFollowup(q)||/^(?:y )?(?:ahora|despues|luego|el siguiente paso|cual es el siguiente paso|que hago ahora|ya (?:lo )?(?:he )?(?:hice|hecho|esta)|no (?:me )?(?:sale|aparece|funciona|deja)|donde esta|donde lo encuentro|no veo el boton|puedes poner un ejemplo)(?: por favor)?$/.test(q);
}
export function helpConversationTopics(guides,message,context,history=[],limit=4){
 const current=ranked(guides,message,context,limit),q=normalizeHelpText(message);
 if(/\b(?:cambiando de tema|otra pregunta|otra cosa|ahora sobre)\b/.test(q)||!helpIsFollowup(message))return current;
 // A named feature can intentionally change the subject even with "eso".
 if(/\b(?:instagram|stripe|showcase|migrations|assist|licencias|banner|avatar|album|contrasena)\b/.test(q)&&current.length)return current;
 for(const previous of helpSafeHistory(history).filter(x=>x.role==='user').reverse()){
  const topic=ranked(guides,previous.content,context,1)[0];
  if(topic)return ranked(guides,`${message} ${topic.title}`,context,limit);
 }
 return current;
}
