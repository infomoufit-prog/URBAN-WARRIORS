export const ASSIST_SPECIALISTS=Object.freeze([
  {id:'management',label:'Gestión',title:'Dirección y prioridades',description:'Resume la situación y ordena los siguientes pasos.',prompt:'Resume la gestión disponible, identifica los tres pendientes más importantes y propón el orden de revisión.'},
  {id:'memberships',label:'Socios y cuotas',title:'Membresías y seguimiento',description:'Ayuda a entender altas, grupos, cuotas y pendientes.',prompt:'Revisa socios, grupos y cuotas del contexto autorizado. Señala datos incompletos y acciones que debería revisar.'},
  {id:'finance',label:'Finanzas',title:'Cifras y conciliación',description:'Explica ingresos, cobros y diferencias sin mover dinero.',prompt:'Explícame las cifras disponibles de forma sencilla, separando cobrado, pendiente y posibles diferencias a revisar.'},
  {id:'stripe',label:'Stripe y cobros',title:'Alta segura y estado de cobros',description:'Guía el onboarding y explica el estado de la cuenta conectada.',prompt:'Ayúdame a revisar el estado de Stripe y los pasos que faltan para activar cobros con tarjeta.'},
  {id:'events',label:'Events',title:'Eventos y entradas',description:'Planifica publicación, ticketing, aforo y operación.',prompt:'Revisa los eventos disponibles, sus pendientes de publicación, venta de entradas y control de aforo.'},
  {id:'showcase',label:'Showcase',title:'Catálogo y pedidos',description:'Ayuda con catálogo, stock, pedidos y posventa.',prompt:'Revisa el estado de Showcase, catálogo, stock y pedidos. Prioriza los problemas que requieren atención.'},
  {id:'marketing',label:'Marketing',title:'Comunicación y crecimiento',description:'Propone campañas basadas solo en datos autorizados.',prompt:'Propón un plan de marketing breve y accionable usando únicamente la información disponible de esta organización.'},
  {id:'federation',label:'Federación',title:'Red, licencias y clubes',description:'Ordena revisiones de clubes, federados y licencias.',prompt:'Resume el estado federativo disponible y prioriza clubes, federados o licencias que necesiten revisión.'}
]);

export const DEFAULT_ASSIST_SPECIALIST='management';

export function assistSpecialist(id){
  return ASSIST_SPECIALISTS.find(item=>item.id===String(id||''))||ASSIST_SPECIALISTS[0];
}

export function specialistFromSubject(subject=''){
  const normalized=String(subject||'').toLowerCase();
  return ASSIST_SPECIALISTS.find(item=>normalized.includes(`· ${item.label.toLowerCase()}`))||ASSIST_SPECIALISTS[0];
}
