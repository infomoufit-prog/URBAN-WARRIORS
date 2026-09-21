import { createClient } from 'npm:@supabase/supabase-js@2.112.3'
import { PDFDocument, StandardFonts, rgb, type PDFPage, type PDFFont } from 'npm:pdf-lib@1.17.1'
import fontkit from 'npm:@pdf-lib/fontkit@1.1.1'

const A4:[number,number]=[595.28,841.89]
const MARGIN=42

function secretKey():string{
  const legacy=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if(legacy)return legacy
  const raw=Deno.env.get('SUPABASE_SECRET_KEYS')
  if(!raw)throw new Error('Missing Supabase secret key')
  const parsed=JSON.parse(raw) as Record<string,string>
  const key=parsed.default||Object.values(parsed)[0]
  if(!key)throw new Error('SUPABASE_SECRET_KEYS is empty')
  return key
}
const cors={'access-control-allow-origin':'*','access-control-allow-headers':'authorization, x-client-info, apikey, content-type, prefer','access-control-allow-methods':'POST, OPTIONS','access-control-max-age':'86400'}
function json(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{...cors,'content-type':'application/json; charset=utf-8','cache-control':'no-store'}})}
function uuid(v:unknown){return typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v)}
function n(v:unknown){const x=Number(v||0);return Number.isFinite(x)?x:0}
const SUPPORTED_LOCALES=new Set(['es','en','fr','pt','it','de','th','fil'])
const LOCALE_TAG:Record<string,string>={es:'es-ES',en:'en-US',fr:'fr-FR',pt:'pt-PT',it:'it-IT',de:'de-DE',th:'th-TH',fil:'fil-PH'}
function normalizeLocale(v:unknown){const raw=String(v||'').trim().toLowerCase().replace('_','-');const base=raw.split('-')[0];return SUPPORTED_LOCALES.has(raw)?raw:SUPPORTED_LOCALES.has(base)?base:'es'}
// Thai PDF support: embed Noto Sans Thai at runtime instead of forcing English.
// The font binary is not packaged with KOMBAX; deployments may override the official
// Google Fonts URL via KOMBAX_THAI_FONT_URL. If fetch/embed fails, the PDF safely falls
// back to English rather than returning corrupted Thai glyphs.
const DEFAULT_THAI_FONT_URL='https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthai/NotoSansThai%5Bwdth%2Cwght%5D.ttf'
async function embedDocumentFonts(pdf:PDFDocument,requested:string){
  if(requested==='th'){
    try{
      pdf.registerFontkit(fontkit)
      const fontUrl=Deno.env.get('KOMBAX_THAI_FONT_URL')||DEFAULT_THAI_FONT_URL
      const response=await fetch(fontUrl,{signal:AbortSignal.timeout(8000)})
      if(!response.ok)throw new Error(`Thai font fetch failed (${response.status})`)
      const bytes=new Uint8Array(await response.arrayBuffer())
      const thai=await pdf.embedFont(bytes,{subset:true})
      return {normal:thai,bold:thai,documentLocale:'th',fontMode:'noto_sans_thai'} as const
    }catch(error){console.warn('[finance-report] Thai font unavailable, using safe English PDF fallback',error)}
  }
  const normal=await pdf.embedFont(StandardFonts.Helvetica),bold=await pdf.embedFont(StandardFonts.HelveticaBold)
  return {normal,bold,documentLocale:requested==='th'?'en':requested,fontMode:'standard'} as const
}
function eur(v:unknown,locale='es'){return `${n(v).toLocaleString(LOCALE_TAG[locale]||LOCALE_TAG.es,{minimumFractionDigits:2,maximumFractionDigits:2})} EUR`}
function pct(v:unknown,locale='es'){return n(v).toLocaleString(LOCALE_TAG[locale]||LOCALE_TAG.es,{minimumFractionDigits:2,maximumFractionDigits:2})}
function clean(v:unknown){return String(v??'').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g,' ').replace(/[–—]/g,'-').replace(/…/g,'...')}
function safeForFont(v:unknown,font:PDFFont){
  const text=clean(v),allowed=new Set(font.getCharacterSet())
  return [...text].map(ch=>{const cp=ch.codePointAt(0)||0;return cp===10||cp===13||allowed.has(cp)?ch:'?'}).join('')
}
function short(v:unknown,max=34){const t=clean(v).replace(/\s+/g,' ').trim();return t.length<=max?t:`${t.slice(0,Math.max(0,max-1))}…`}
function hex(value:unknown,fallback=[0.82,0.08,0.10] as [number,number,number]){
  const m=/^#([0-9a-f]{6})$/i.exec(String(value||''));if(!m)return fallback
  const x=parseInt(m[1],16);return [((x>>16)&255)/255,((x>>8)&255)/255,(x&255)/255] as [number,number,number]
}
function wrap(text:string,font:PDFFont,size:number,width:number){
  const words=safeForFont(text,font).split(/\s+/).filter(Boolean),lines:string[]=[];let line=''
  for(const word of words){const next=line?`${line} ${word}`:word;if(font.widthOfTextAtSize(next,size)<=width)line=next;else{if(line)lines.push(line);line=word}}
  if(line)lines.push(line);return lines.length?lines:['']
}
function drawText(page:PDFPage,font:PDFFont,text:string,x:number,y:number,size=9,opts:{maxWidth?:number;color?:[number,number,number]}={}){
  const c=opts.color||[0.12,0.14,0.17];page.drawText(safeForFont(text,font),{x,y,size,font,color:rgb(c[0],c[1],c[2]),maxWidth:opts.maxWidth})
}
const PDF_COPY:Record<string,any>={
 es:{financialReport:'Informe financiero KOMBAX',version:'Versión',period:'Periodo',to:'a',generated:'Generado',generatedBy:'Generado por',authorizedUser:'Usuario autorizado',records:'registros',kpiGenerated:'Generado',collected:'Cobrado',pending:'Pendiente',overdue:'Vencido',collectionPercentage:'Porcentaje de cobro',studentsWithDebt:'Alumnos con deuda',monthlyEvolution:'Evolución mensual · Histograma mensual',monthlyLegend:'Generado / Cobrado / Pendiente',debtAging:'Antigüedad de la deuda',filters:'Filtros',student:'Alumno',concept:'Concepto',amount:'Importe',status:'Estado',financialDetail:'Detalle financiero',continued:'continuación',noMovements:'No hay movimientos que coincidan con los filtros del informe.',historicalNote:'Nota histórica',defaultHistoricalNote:'Este informe es un snapshot histórico inmutable.',page:'Página',privateReport:'KOMBAX · Informe financiero privado',aging:{sin_vencer:'Sin vencer','1_15':'1-15 días','16_30':'16-30 días','31_60':'31-60 días','60_plus':'+60 días'},types:{vista_actual:'Vista financiera',tesoreria_mensual:'Tesorería mensual',tesoreria_anual:'Tesorería anual',cobros:'Cobros',pendientes:'Pendientes',vencidos:'Vencidos',por_grupo:'Por grupo',por_disciplina:'Por disciplina',por_categoria:'Por categoría',por_metodo_pago:'Por método de pago',licencias:'Licencias',competiciones:'Competiciones',eventos:'Eventos',estado_cuenta:'Estado de cuenta'}},
 en:{financialReport:'KOMBAX financial report',version:'Version',period:'Period',to:'to',generated:'Generated',generatedBy:'Generated by',authorizedUser:'Authorized user',records:'records',kpiGenerated:'Generated',collected:'Collected',pending:'Pending',overdue:'Overdue',collectionPercentage:'Collection percentage',studentsWithDebt:'Students with debt',monthlyEvolution:'Monthly evolution · Monthly histogram',monthlyLegend:'Generated / Collected / Pending',debtAging:'Debt aging',filters:'Filters',student:'Student',concept:'Concept',amount:'Amount',status:'Status',financialDetail:'Financial detail',continued:'continued',noMovements:'No transactions match the report filters.',historicalNote:'Historical note',defaultHistoricalNote:'This report is an immutable historical snapshot.',page:'Page',privateReport:'KOMBAX · Private financial report',aging:{sin_vencer:'Not due','1_15':'1-15 days','16_30':'16-30 days','31_60':'31-60 days','60_plus':'60+ days'},types:{vista_actual:'Financial view',tesoreria_mensual:'Monthly treasury',tesoreria_anual:'Annual treasury',cobros:'Collections',pendientes:'Pending',vencidos:'Overdue',por_grupo:'By group',por_disciplina:'By discipline',por_categoria:'By category',por_metodo_pago:'By payment method',licencias:'Licenses',competiciones:'Competitions',eventos:'Events',estado_cuenta:'Account statement'}},
 fr:{financialReport:'Rapport financier KOMBAX',version:'Version',period:'Période',to:'à',generated:'Généré',generatedBy:'Généré par',authorizedUser:'Utilisateur autorisé',records:'enregistrements',kpiGenerated:'Généré',collected:'Encaissé',pending:'En attente',overdue:'En retard',collectionPercentage:'Taux d’encaissement',studentsWithDebt:'Élèves avec dette',monthlyEvolution:'Évolution mensuelle · Histogramme mensuel',monthlyLegend:'Généré / Encaissé / En attente',debtAging:'Ancienneté de la dette',filters:'Filtres',student:'Élève',concept:'Concept',amount:'Montant',status:'Statut',financialDetail:'Détail financier',continued:'suite',noMovements:'Aucun mouvement ne correspond aux filtres du rapport.',historicalNote:'Note historique',defaultHistoricalNote:'Ce rapport est un instantané historique immuable.',page:'Page',privateReport:'KOMBAX · Rapport financier privé',aging:{sin_vencer:'Non échu','1_15':'1-15 jours','16_30':'16-30 jours','31_60':'31-60 jours','60_plus':'+60 jours'},types:{vista_actual:'Vue financière',tesoreria_mensual:'Trésorerie mensuelle',tesoreria_anual:'Trésorerie annuelle',cobros:'Encaissements',pendientes:'En attente',vencidos:'En retard',por_grupo:'Par groupe',por_disciplina:'Par discipline',por_categoria:'Par catégorie',por_metodo_pago:'Par moyen de paiement',licencias:'Licences',competiciones:'Compétitions',eventos:'Événements',estado_cuenta:'Relevé de compte'}},
 pt:{financialReport:'Relatório financeiro KOMBAX',version:'Versão',period:'Período',to:'a',generated:'Gerado',generatedBy:'Gerado por',authorizedUser:'Utilizador autorizado',records:'registos',kpiGenerated:'Gerado',collected:'Cobrado',pending:'Pendente',overdue:'Vencido',collectionPercentage:'Percentagem de cobrança',studentsWithDebt:'Alunos com dívida',monthlyEvolution:'Evolução mensal · Histograma mensal',monthlyLegend:'Gerado / Cobrado / Pendente',debtAging:'Antiguidade da dívida',filters:'Filtros',student:'Aluno',concept:'Conceito',amount:'Valor',status:'Estado',financialDetail:'Detalhe financeiro',continued:'continuação',noMovements:'Não existem movimentos que correspondam aos filtros do relatório.',historicalNote:'Nota histórica',defaultHistoricalNote:'Este relatório é um snapshot histórico imutável.',page:'Página',privateReport:'KOMBAX · Relatório financeiro privado',aging:{sin_vencer:'Por vencer','1_15':'1-15 dias','16_30':'16-30 dias','31_60':'31-60 dias','60_plus':'+60 dias'},types:{vista_actual:'Vista financeira',tesoreria_mensual:'Tesouraria mensal',tesoreria_anual:'Tesouraria anual',cobros:'Cobranças',pendientes:'Pendentes',vencidos:'Vencidos',por_grupo:'Por grupo',por_disciplina:'Por disciplina',por_categoria:'Por categoria',por_metodo_pago:'Por método de pagamento',licencias:'Licenças',competiciones:'Competições',eventos:'Eventos',estado_cuenta:'Extrato de conta'}},
 it:{financialReport:'Rapporto finanziario KOMBAX',version:'Versione',period:'Periodo',to:'a',generated:'Generato',generatedBy:'Generato da',authorizedUser:'Utente autorizzato',records:'registrazioni',kpiGenerated:'Generato',collected:'Incassato',pending:'In sospeso',overdue:'Scaduto',collectionPercentage:'Percentuale di incasso',studentsWithDebt:'Allievi con debito',monthlyEvolution:'Andamento mensile · Istogramma mensile',monthlyLegend:'Generato / Incassato / In sospeso',debtAging:'Anzianità del debito',filters:'Filtri',student:'Allievo',concept:'Voce',amount:'Importo',status:'Stato',financialDetail:'Dettaglio finanziario',continued:'continua',noMovements:'Nessun movimento corrisponde ai filtri del rapporto.',historicalNote:'Nota storica',defaultHistoricalNote:'Questo rapporto è uno snapshot storico immutabile.',page:'Pagina',privateReport:'KOMBAX · Rapporto finanziario privato',aging:{sin_vencer:'Non scaduto','1_15':'1-15 giorni','16_30':'16-30 giorni','31_60':'31-60 giorni','60_plus':'+60 giorni'},types:{vista_actual:'Vista finanziaria',tesoreria_mensual:'Tesoreria mensile',tesoreria_anual:'Tesoreria annuale',cobros:'Incassi',pendientes:'In sospeso',vencidos:'Scaduti',por_grupo:'Per gruppo',por_disciplina:'Per disciplina',por_categoria:'Per categoria',por_metodo_pago:'Per metodo di pagamento',licencias:'Licenze',competiciones:'Competizioni',eventos:'Eventi',estado_cuenta:'Estratto conto'}},
 de:{financialReport:'KOMBAX Finanzbericht',version:'Version',period:'Zeitraum',to:'bis',generated:'Erstellt',generatedBy:'Erstellt von',authorizedUser:'Autorisierter Benutzer',records:'Einträge',kpiGenerated:'Erstellt',collected:'Bezahlt',pending:'Offen',overdue:'Überfällig',collectionPercentage:'Zahlungsquote',studentsWithDebt:'Schüler mit Schulden',monthlyEvolution:'Monatliche Entwicklung · Monatshistogramm',monthlyLegend:'Erstellt / Bezahlt / Offen',debtAging:'Forderungsalter',filters:'Filter',student:'Schüler',concept:'Posten',amount:'Betrag',status:'Status',financialDetail:'Finanzdetails',continued:'Fortsetzung',noMovements:'Keine Bewegungen entsprechen den Berichtsfiltern.',historicalNote:'Historischer Hinweis',defaultHistoricalNote:'Dieser Bericht ist ein unveränderlicher historischer Snapshot.',page:'Seite',privateReport:'KOMBAX · Privater Finanzbericht',aging:{sin_vencer:'Nicht fällig','1_15':'1-15 Tage','16_30':'16-30 Tage','31_60':'31-60 Tage','60_plus':'60+ Tage'},types:{vista_actual:'Finanzansicht',tesoreria_mensual:'Monatliche Kasse',tesoreria_anual:'Jährliche Kasse',cobros:'Zahlungen',pendientes:'Offen',vencidos:'Überfällig',por_grupo:'Nach Gruppe',por_disciplina:'Nach Disziplin',por_categoria:'Nach Kategorie',por_metodo_pago:'Nach Zahlungsmethode',licencias:'Lizenzen',competiciones:'Wettkämpfe',eventos:'Events',estado_cuenta:'Kontoauszug'}},
 fil:{financialReport:'KOMBAX financial report',version:'Bersyon',period:'Panahon',to:'hanggang',generated:'Nagawa',generatedBy:'Ginawa ni',authorizedUser:'Awtorisadong user',records:'record',kpiGenerated:'Nagawa',collected:'Nakolekta',pending:'Nakabinbin',overdue:'Lagpas sa takdang petsa',collectionPercentage:'Porsiyento ng koleksyon',studentsWithDebt:'Mga mag-aaral na may utang',monthlyEvolution:'Buwanang galaw · Buwanang histogram',monthlyLegend:'Nagawa / Nakolekta / Nakabinbin',debtAging:'Edad ng utang',filters:'Mga filter',student:'Mag-aaral',concept:'Konsepto',amount:'Halaga',status:'Status',financialDetail:'Detalye sa pananalapi',continued:'karugtong',noMovements:'Walang galaw na tumutugma sa mga filter ng ulat.',historicalNote:'Makasaysayang tala',defaultHistoricalNote:'Ang ulat na ito ay isang hindi nababagong historical snapshot.',page:'Pahina',privateReport:'KOMBAX · Pribadong financial report',aging:{sin_vencer:'Hindi pa due','1_15':'1-15 araw','16_30':'16-30 araw','31_60':'31-60 araw','60_plus':'60+ araw'},types:{vista_actual:'Financial view',tesoreria_mensual:'Buwanang treasury',tesoreria_anual:'Taunang treasury',cobros:'Mga koleksyon',pendientes:'Nakabinbin',vencidos:'Overdue',por_grupo:'Ayon sa grupo',por_disciplina:'Ayon sa disiplina',por_categoria:'Ayon sa kategorya',por_metodo_pago:'Ayon sa paraan ng bayad',licencias:'Mga lisensya',competiciones:'Mga kompetisyon',eventos:'Mga event',estado_cuenta:'Account statement'}}
}
function reportTypeLabel(type:string,c:any){return c.types?.[type]||type}

async function embedLogo(pdf:PDFDocument,url:unknown){
  const value=String(url||'').trim();if(!/^https:\/\//i.test(value))return null
  try{const res=await fetch(value,{signal:AbortSignal.timeout(4500)});if(!res.ok)return null;const bytes=new Uint8Array(await res.arrayBuffer());const type=res.headers.get('content-type')||'';if(/png/i.test(type)||/\.png(?:\?|$)/i.test(value))return await pdf.embedPng(bytes);if(/jpe?g/i.test(type)||/\.jpe?g(?:\?|$)/i.test(value))return await pdf.embedJpg(bytes)}catch{/* optional branding */}return null
}

async function buildPdf(payload:any,requestedLocale='es'){
  const snap=payload.snapshot||{},club=snap.club||{},summary=snap.totales||{},months=Array.isArray(snap.meses)?snap.meses:[],rows=Array.isArray(snap.rows)?snap.rows:[]
  const pdf=await PDFDocument.create();const fonts=await embedDocumentFonts(pdf,requestedLocale);const locale=fonts.documentLocale;const c=PDF_COPY[locale]||PDF_COPY.es;const {normal,bold}=fonts
  pdf.setTitle(clean(snap.titulo||payload.titulo||c.financialReport));pdf.setSubject(`KOMBAX Finance Premium · ${clean(payload.identificador)}`);pdf.setCreator('KOMBAX Finance Premium 2.0');pdf.setProducer('KOMBAX');
  const logo=await embedLogo(pdf,club.logo_url);const accent=hex(club.color_primario)
  let page=pdf.addPage(A4);let y=A4[1]-MARGIN
  const header=(p:PDFPage,compact=false)=>{
    p.drawRectangle({x:0,y:A4[1]-8,width:A4[0],height:8,color:rgb(accent[0],accent[1],accent[2])})
    if(logo&&!compact){const scale=Math.min(64/logo.width,40/logo.height);p.drawImage(logo,{x:MARGIN,y:A4[1]-MARGIN-38,width:logo.width*scale,height:logo.height*scale})}
    const tx=logo&&!compact?MARGIN+74:MARGIN
    drawText(p,bold,clean(club.nombre||'Club KOMBAX'),tx,A4[1]-MARGIN-8,14)
    drawText(p,normal,[club.cif?`CIF/NIF ${club.cif}`:'',club.email,club.telefono].filter(Boolean).join(' · '),tx,A4[1]-MARGIN-23,7,{color:[0.38,0.42,0.47]})
    return A4[1]-MARGIN-(compact?34:62)
  }
  y=header(page)
  drawText(page,bold,clean(snap.titulo||payload.titulo||reportTypeLabel(payload.tipo,c)),MARGIN,y,19);y-=22
  drawText(page,normal,`${clean(payload.identificador)} · ${c.version} ${payload.version||1} · ${reportTypeLabel(payload.tipo||snap.tipo||'',c)}`,MARGIN,y,8,{color:[0.38,0.42,0.47]});y-=16
  const period=snap.periodo||{};const actor=snap.generado_por||{};const generated=new Date(snap.generado_en||payload.generado_en||Date.now()).toLocaleString(LOCALE_TAG[locale]||LOCALE_TAG.es,{timeZone:club.zona_horaria||'Europe/Madrid'})
  drawText(page,normal,`${c.period}: ${period.desde||'—'} ${c.to} ${period.hasta||'—'} · ${c.generated}: ${generated}`,MARGIN,y,8);y-=13
  drawText(page,normal,`${c.generatedBy}: ${clean(`${actor.nombre||''} ${actor.apellidos||''}`.trim()||c.authorizedUser)} · ${rows.length} ${c.records}`,MARGIN,y,8);y-=24

  const kpis=[[c.kpiGenerated,summary.generado],[c.collected,summary.cobrado],[c.pending,summary.pendiente],[c.overdue,summary.vencido]] as const;const gap=8,w=(A4[0]-2*MARGIN-gap*3)/4
  for(let i=0;i<kpis.length;i++){const x=MARGIN+i*(w+gap);page.drawRectangle({x,y:y-48,width:w,height:48,borderWidth:.7,borderColor:rgb(.82,.84,.87),color:rgb(.97,.975,.98)});drawText(page,normal,kpis[i][0],x+9,y-15,7,{color:[.38,.42,.47]});drawText(page,bold,eur(kpis[i][1],locale),x+9,y-34,11)}
  y-=66
  drawText(page,bold,`${c.collectionPercentage}: ${pct(summary.porcentaje_cobro,locale)} % · ${c.studentsWithDebt}: ${n(summary.alumnos_con_deuda)}`,MARGIN,y,9);y-=22

  if(months.length){
    drawText(page,bold,c.monthlyEvolution,MARGIN,y,10);y-=13
    drawText(page,normal,c.monthlyLegend,MARGIN,y,7,{color:[.38,.42,.47]});y-=12
    const chartH=108,chartW=A4[0]-2*MARGIN,max=Math.max(1,...months.flatMap((m:any)=>[n(m.generado),n(m.cobrado),n(m.pendiente)]));
    const display=months.slice(-12),slot=chartW/Math.max(1,display.length),bar=Math.max(4,Math.min(11,(slot-12)/3)),base=y-chartH;
    ;[0,.5,1].forEach(fr=>{const yy=base+fr*(chartH-18);page.drawLine({start:{x:MARGIN,y:yy},end:{x:MARGIN+chartW,y:yy},thickness:.35,color:rgb(.86,.87,.89)});drawText(page,normal,eur(max*(1-fr),locale),MARGIN,yy+2,5.6,{color:[.46,.49,.54]})})
    display.forEach((m:any,i:number)=>{const x=MARGIN+i*slot+10,values=[n(m.generado),n(m.cobrado),n(m.pendiente)],cols=[[.72,.75,.79],[accent[0],accent[1],accent[2]],[.36,.40,.46]] as [number,number,number][];values.forEach((v,j)=>{const h=(v/max)*(chartH-22);page.drawRectangle({x:x+j*(bar+3),y:base,width:bar,height:Math.max(1,h),color:rgb(cols[j][0],cols[j][1],cols[j][2])})});drawText(page,normal,String(m.mes||'').slice(5,7),x+bar,base-10,6,{color:[.38,.42,.47]})})
    const ly=base-25;[[c.kpiGenerated,[.72,.75,.79]],[c.collected,accent],[c.pending,[.36,.40,.46]]].forEach((it:any,i:number)=>{const x=MARGIN+i*105;page.drawRectangle({x,y:ly,width:8,height:8,color:rgb(it[1][0],it[1][1],it[1][2])});drawText(page,normal,it[0],x+12,ly+1,6.5)})
    y=ly-17
  }

  const aging=Array.isArray(snap.antiguedad)?snap.antiguedad:[]
  if(aging.length&&y>MARGIN+125){
    drawText(page,bold,c.debtAging,MARGIN,y,10);y-=14
    const labels:Record<string,string>=c.aging
    const vals=aging.map((a:any)=>n(a.total)),amax=Math.max(1,...vals),labelW=82,amountW=62,trackW=A4[0]-2*MARGIN-labelW-amountW-14
    aging.slice(0,5).forEach((a:any,i:number)=>{const val=n(a.total),yy=y-i*18;drawText(page,normal,labels[String(a.bucket)]||String(a.bucket||''),MARGIN,yy,7);page.drawRectangle({x:MARGIN+labelW,y:yy-2,width:trackW,height:8,color:rgb(.92,.93,.94)});page.drawRectangle({x:MARGIN+labelW,y:yy-2,width:Math.max(1,trackW*val/amax),height:8,color:rgb(accent[0],accent[1],accent[2]),opacity:.78});drawText(page,bold,eur(val,locale),A4[0]-MARGIN-amountW+3,yy,7)})
    y-=aging.slice(0,5).length*18+10
  }


  const filterLabels=snap.filtros_etiquetas||{};const filterText=Object.entries(filterLabels).filter(([,v])=>String(v||'').trim()).map(([k,v])=>`${k}: ${v}`).join(' · ')
  if(filterText){drawText(page,bold,c.filters,MARGIN,y,9);y-=12;for(const line of wrap(filterText,normal,7,A4[0]-2*MARGIN)){drawText(page,normal,line,MARGIN,y,7);y-=10}y-=6}

  const tableHeader=(p:PDFPage,startY:number)=>{const cols=[[c.student,116],[c.concept,110],[c.period,52],[c.amount,55],[c.collected,55],[c.pending,55],[c.status,62]] as const;let x=MARGIN;p.drawRectangle({x:MARGIN,y:startY-15,width:A4[0]-2*MARGIN,height:17,color:rgb(.93,.94,.95)});for(const [label,cw] of cols){drawText(p,bold,label,x+3,startY-10,6.5);x+=cw}return startY-19}
  if(rows.length){drawText(page,bold,c.financialDetail,MARGIN,y,10);y-=14;y=tableHeader(page,y);for(const r of rows){if(y<MARGIN+34){page=pdf.addPage(A4);y=header(page,true);drawText(page,bold,`${c.financialDetail} (${c.continued})`,MARGIN,y,9);y-=13;y=tableHeader(page,y)}const cells=[short(`${r.socio_apellidos||''}, ${r.socio_nombre||''}`,26),short(r.concepto,24),String(r.periodo||'').slice(0,7),eur(r.importe,locale),eur(r.pagado_validado,locale),eur(r.saldo,locale),short(r.estado,14)],widths=[116,110,52,55,55,55,62];let x=MARGIN;for(let i=0;i<cells.length;i++){drawText(page,normal,cells[i],x+3,y,6.2,{maxWidth:widths[i]-5});x+=widths[i]}page.drawLine({start:{x:MARGIN,y:y-4},end:{x:A4[0]-MARGIN,y:y-4},thickness:.25,color:rgb(.88,.89,.91)});y-=13}}
  if(!rows.length){drawText(page,normal,c.noMovements,MARGIN,y,9);y-=18}

  if(y<MARGIN+60){page=pdf.addPage(A4);y=header(page,true)}
  y-=8;drawText(page,bold,c.historicalNote,MARGIN,y,8);y-=12;for(const line of wrap(clean(snap.nota_historica||c.defaultHistoricalNote),normal,7,A4[0]-2*MARGIN)){drawText(page,normal,line,MARGIN,y,7,{color:[.38,.42,.47]});y-=10}

  const pages=pdf.getPages();pages.forEach((p,i)=>{p.drawLine({start:{x:MARGIN,y:28},end:{x:A4[0]-MARGIN,y:28},thickness:.4,color:rgb(.82,.84,.87)});drawText(p,normal,`${clean(payload.identificador)} · ${c.page} ${i+1}/${pages.length}`,MARGIN,16,6.5,{color:[.42,.45,.5]});const right=c.privateReport;const rw=normal.widthOfTextAtSize(right,6.5);drawText(p,normal,right,A4[0]-MARGIN-rw,16,6.5,{color:[.42,.45,.5]})})
  return {bytes:new Uint8Array(await pdf.save()),documentLocale:locale,fontMode:fonts.fontMode}
}

Deno.serve(async(req)=>{
  const requestId=crypto.randomUUID()
  try{
    if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors})
    if(req.method!=='POST')return json({error:'Method not allowed',request_id:requestId},405)
    const auth=req.headers.get('authorization')||'';if(!/^Bearer\s+.+/i.test(auth))return json({error:'AUTH_REQUIRED',request_id:requestId},401)
    const body=await req.json().catch(()=>({}));const requestedLocale=normalizeLocale(body.user_locale);if(!uuid(body.report_id))return json({error:'invalid_report_id',request_id:requestId},400)
    const url=Deno.env.get('SUPABASE_URL')!,anon=Deno.env.get('SUPABASE_ANON_KEY')||Deno.env.get('SUPABASE_PUBLISHABLE_KEY')!
    const user=createClient(url,anon,{global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}})
    const {data:payload,error:accessError}=await user.rpc('app_finance_v2_report_payload_v145',{p_report_id:body.report_id})
    if(accessError||!payload?.id)return json({error:'FINANCE_REPORT_FORBIDDEN',request_id:requestId},403)
    if(payload.archivo_path)return json({ok:true,existing:true,report_id:payload.id,archivo_path:payload.archivo_path,requested_locale:requestedLocale,document_locale:null,request_id:requestId})

    const built=await buildPdf(payload,requestedLocale);const bytes=built.bytes;const pdfLocale=built.documentLocale;if(bytes.byteLength>20*1024*1024)throw new Error('Generated PDF exceeds 20 MB')
    const hashBytes=new Uint8Array(await crypto.subtle.digest('SHA-256',bytes));const sha=[...hashBytes].map(x=>x.toString(16).padStart(2,'0')).join('')
    const year=String(payload.snapshot?.generado_en||payload.generado_en||new Date().toISOString()).slice(0,4)||String(new Date().getFullYear())
    const path=`${payload.club_id}/${year}/${payload.identificador}.pdf`
    const service=createClient(url,secretKey(),{auth:{persistSession:false,autoRefreshToken:false}})
    const {error:uploadError}=await service.storage.from('finance-reports').upload(path,bytes,{contentType:'application/pdf',upsert:true,cacheControl:'private, max-age=0'})
    if(uploadError)throw uploadError
    const {error:attachError}=await service.rpc('app_finance_v2_report_file_attach_v145',{p_report_id:payload.id,p_path:path,p_bytes:bytes.byteLength,p_sha256:sha})
    if(attachError)throw attachError
    return json({ok:true,report_id:payload.id,identificador:payload.identificador,archivo_path:path,archivo_bytes:bytes.byteLength,archivo_sha256:sha,requested_locale:requestedLocale,document_locale:pdfLocale,font_mode:built.fontMode,request_id:requestId})
  }catch(error){console.error(`[finance-report ${requestId}]`,error);return json({error:'FINANCE_REPORT_GENERATION_FAILED',request_id:requestId},500)}
})
