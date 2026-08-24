const A4={w:595.28,h:841.89};
const money=v=>`${Number(v||0).toLocaleString('es-ES',{minimumFractionDigits:2,maximumFractionDigits:2})} €`;
const date=v=>{if(!v)return '—';const d=new Date(`${String(v).slice(0,10)}T12:00:00`);return Number.isNaN(d.getTime())?String(v):d.toLocaleDateString('es-ES')};
const plain=v=>String(v??'').replace(/[\r\n\t]+/g,' ').replace(/\s+/g,' ').trim();
const fit=(v,n)=>{const s=plain(v);return s.length<=n?s:`${s.slice(0,Math.max(1,n-1))}…`};
const pdfEscape=s=>plain(s).replace(/\\/g,'\\\\').replace(/\(/g,'\\(').replace(/\)/g,'\\)');

function winAnsiBytes(text){
  const out=[];for(const ch of text){const code=ch==='€'?128:ch.charCodeAt(0);out.push(code<=255?code:63);}return Uint8Array.from(out);
}
function byteLength(text){return winAnsiBytes(text).length;}
function textCmd(x,y,size,text,font='F1') {return `BT /${font} ${size} Tf ${x.toFixed(2)} ${y.toFixed(2)} Td (${pdfEscape(text)}) Tj ET\n`;}
function lineCmd(x1,y1,x2,y2,width=.5){return `${width} w ${x1.toFixed(2)} ${y1.toFixed(2)} m ${x2.toFixed(2)} ${y2.toFixed(2)} l S\n`;}
function rectCmd(x,y,w,h,fill=.92){return `${fill} g ${x.toFixed(2)} ${y.toFixed(2)} ${w.toFixed(2)} ${h.toFixed(2)} re f 0 g\n`;}

function filtersLabel(filters={}){
  const labels=[];
  if(filters.year)labels.push(`Año ${filters.year}`);if(filters.month)labels.push(`Mes ${filters.month}`);
  if(filters.date_from||filters.date_to)labels.push(`${filters.date_from||'…'} → ${filters.date_to||'…'}`);
  if(filters.categoria)labels.push(`Categoría ${filters.categoria}`);if(filters.estado)labels.push(`Estado ${filters.estado}`);
  if(filters.aging)labels.push(`Antigüedad ${filters.aging}`);if(filters.metodo)labels.push(`Método ${filters.metodo}`);
  return labels.length?labels.join(' · '):'Vista completa';
}

function firstPage(snapshot,page,total){
  const brand=snapshot.resumen?.branding||snapshot.resumen?.dashboard?.branding||{};
  const dash=snapshot.resumen?.dashboard||{};const summary=dash.summary||{};const months=dash.months||[];
  let s='';
  s+=textCmd(42,800,10,'KOMBAX · FINANZAS PREMIUM 2.0','F2');
  s+=textCmd(42,778,20,fit(snapshot.titulo||'Informe financiero',52),'F2');
  s+=textCmd(42,758,10,`${fit(brand.nombre||'Club',45)} · ${snapshot.identificador||'—'} · v${snapshot.version||1}`);
  s+=textCmd(42,742,8,`Generado ${new Date().toLocaleString('es-ES')} · ${filtersLabel(snapshot.filtros||{})}`);
  s+=lineCmd(42,730,553,730,1);
  const cards=[['GENERADO',summary.generado],['COBRADO',summary.cobrado],['PENDIENTE',summary.pendiente],['VENCIDO',summary.vencido],['COBRO',`${Number(summary.porcentaje_cobro||0).toFixed(1)} %`]];
  cards.forEach(([label,value],i)=>{const x=42+i*102;s+=rectCmd(x,675,94,42,.95);s+=textCmd(x+8,704,7,label,'F2');s+=textCmd(x+8,685,11,typeof value==='string'?value:money(value),'F2');});
  s+=textCmd(42,650,11,'Evolución mensual · generado / cobrado / pendiente','F2');
  const chartX=42,chartY=520,chartW=510,chartH=108;const visible=months.slice(-12);const max=Math.max(1,...visible.flatMap(m=>[Number(m.generado||0),Number(m.cobrado||0),Number(m.pendiente||0)]));
  s+=lineCmd(chartX,chartY,chartX+chartW,chartY,.5);
  visible.forEach((m,i)=>{const slot=chartW/Math.max(1,visible.length),baseX=chartX+i*slot+3;const vals=[Number(m.generado||0),Number(m.cobrado||0),Number(m.pendiente||0)];vals.forEach((v,j)=>{const h=Math.max(1,(v/max)*(chartH-18));const shade=[.25,.5,.75][j];s+=`${shade} g ${(baseX+j*5).toFixed(2)} ${chartY.toFixed(2)} 4 ${h.toFixed(2)} re f 0 g\n`;});s+=textCmd(baseX,chartY-12,5,String(m.mes||'').slice(5,7));});
  s+=textCmd(42,490,8,'Leyenda: ■ generado   ■ cobrado   ■ pendiente');
  s+=textCmd(42,462,11,'Resumen administrativo','F2');
  const notes=[
    `Alumnos con deuda: ${summary.alumnos_con_deuda||0}`,
    `Cargos incluidos: ${summary.cargos||0}`,
    `Pagos por validar: ${dash.attention?.pagos_por_validar||0}`,
    `Automatizaciones con error (30 días): ${dash.attention?.errores_automatizacion||0}`
  ];notes.forEach((n,i)=>{s+=textCmd(50,440-i*18,9,n)});
  s+=textCmd(42,350,9,`CIF/NIF: ${brand.cif||'—'} · ${brand.email||'—'} · ${brand.telefono||'—'}`);
  s+=textCmd(42,334,8,fit(`${brand.direccion||''}${brand.web?` · ${brand.web}`:''}`,90));
  s+=textCmd(42,302,8,'Documento administrativo de gestión. No constituye una factura fiscal.');
  s+=footer(page,total,snapshot);return s;
}

function tablePage(snapshot,rows,page,total,start){
  let s='';s+=textCmd(42,800,9,`${snapshot.identificador||'KOMBAX'} · Detalle financiero`,'F2');s+=textCmd(42,784,7,filtersLabel(snapshot.filtros||{}));s+=lineCmd(42,773,553,773,.7);
  const cols=[['Alumno',42,18],['Concepto',130,22],['Cat.',244,10],['Periodo',294,10],['Importe',346,11],['Cobrado',400,11],['Pendiente',456,11],['Vence',514,10]];
  cols.forEach(([h,x])=>{s+=textCmd(x,754,6,h,'F2')});s+=lineCmd(42,747,553,747,.5);
  let y=731;for(const r of rows){
    const name=fit(`${r.socio_nombre||''} ${r.socio_apellidos||''}`,18);const values=[name,fit(r.concepto,22),fit(r.categoria,10),String(r.periodo||'').slice(0,7),money(r.importe),money(r.pagado_validado),money(r.saldo),date(r.vencimiento)];
    values.forEach((v,i)=>s+=textCmd(cols[i][1],y,6,String(v)));s+=lineCmd(42,y-6,553,y-6,.18);y-=18;
  }
  s+=textCmd(42,52,7,`Filas ${start+1}–${start+rows.length} de ${(snapshot.dataset||[]).length}`);s+=footer(page,total,snapshot);return s;
}
function footer(page,total,snapshot){return lineCmd(42,34,553,34,.4)+textCmd(42,20,6,`KOMBAX · ${snapshot.identificador||'Informe'} · snapshot histórico`)+textCmd(510,20,6,`${page}/${total}`);}

function assemblePdf(streams){
  const objects=[];const add=body=>{objects.push(body);return objects.length;};
  const font1=add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');
  const font2=add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>');
  const pagesId=3;objects.push('PAGES_PLACEHOLDER'); // id 3
  const pageIds=[];
  for(const stream of streams){const contentId=add(`<< /Length ${byteLength(stream)} >>\nstream\n${stream}endstream`);const pageId=add(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${A4.w} ${A4.h}] /Resources << /Font << /F1 ${font1} 0 R /F2 ${font2} 0 R >> >> /Contents ${contentId} 0 R >>`);pageIds.push(pageId);}
  objects[pagesId-1]=`<< /Type /Pages /Count ${pageIds.length} /Kids [${pageIds.map(id=>`${id} 0 R`).join(' ')}] >>`;
  const catalogId=add(`<< /Type /Catalog /Pages ${pagesId} 0 R >>`);
  let body='%PDF-1.4\n%âãÏÓ\n';const offsets=[0];
  objects.forEach((obj,i)=>{offsets.push(byteLength(body));body+=`${i+1} 0 obj\n${obj}\nendobj\n`;});
  const xref=byteLength(body);body+=`xref\n0 ${objects.length+1}\n0000000000 65535 f \n`;for(let i=1;i<offsets.length;i++)body+=`${String(offsets[i]).padStart(10,'0')} 00000 n \n`;
  body+=`trailer\n<< /Size ${objects.length+1} /Root ${catalogId} 0 R >>\nstartxref\n${xref}\n%%EOF`;
  return new Blob([winAnsiBytes(body)],{type:'application/pdf'});
}

export function buildFinanceReportPdf(snapshot){
  const dataset=Array.isArray(snapshot?.dataset)?snapshot.dataset:[];const perPage=35;const detailPages=Math.max(1,Math.ceil(dataset.length/perPage));const total=1+detailPages;const streams=[firstPage(snapshot,1,total)];
  for(let p=0;p<detailPages;p++)streams.push(tablePage(snapshot,dataset.slice(p*perPage,(p+1)*perPage),p+2,total,p*perPage));
  return assemblePdf(streams);
}

export async function sha256Blob(blob){
  const bytes=await blob.arrayBuffer();const hash=await crypto.subtle.digest('SHA-256',bytes);return [...new Uint8Array(hash)].map(x=>x.toString(16).padStart(2,'0')).join('');
}
