import fs from 'node:fs';

const entry={
  id:'r108-finance-club',
  code:'FINANZAS',
  kind:'finance',
  active:true,
  edition:'R108',
  title:'Guía completa de Finanzas para clubes',
  subtitle:'Cargos, cuotas, automatizaciones, avisos, cobros con tarjeta, recibos e informes explicados paso a paso.',
  scope:'Clubes, equipo de gestión, miembros y familias',
  territory:'',
  pdf:'./assets/guides/finance/KOMBAX_GUIA_FINANZAS_CLUB.pdf',
  case_specific:false,
  consult_triggers:[]
};

for(const path of ['web/assets/guides/runtime-index.json','web/assets/guides/catalog.json']){
  const data=JSON.parse(fs.readFileSync(path,'utf8'));
  data.entries=(data.entries||[]).filter(x=>x.id!==entry.id);
  if(path.includes('runtime-index'))data.finance_guide=entry;
  data.version=path.includes('runtime-index')?'20145-r92-resource-center':'20144-r91-public-guides-r100-1';
  fs.writeFileSync(path,JSON.stringify(data,null,2)+'\n','utf8');
}
console.log('Finance guide registered in KOMBAX Guides');
