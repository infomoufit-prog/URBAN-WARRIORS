import {PGlite} from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const db=new PGlite();let passed=0;
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const club=id(1),student=id(2),parent=id(3),admin=id(4);
const ok=(label,value)=>{assert.ok(value,label);passed++;};
const as=u=>db.query("select set_config('request.jwt.claim.sub',$1,false)",[u||'']);
const reject=async(f,pattern)=>{await assert.rejects(f,pattern);passed++;};
const amount=async(fee)=>(await db.query("select coalesce(sum(importe),0)::text paid from pagos where cuota_id=$1 and estado_validacion='validado'",[fee])).rows[0].paid;
const communicate=async(fee,value)=>(await db.query("select (comunicar_pago_cuota($1,$2,current_date,'transferencia')).id id",[fee,value])).rows[0].id;
const validate=pay=>db.query("select validar_pago_cuota($1,'validado')",[pay]);
try{
 await db.exec(`create schema auth;create schema private;
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create type rol_club as enum('direccion','secretaria','economia');
 create type estado_cuota as enum('pendiente','pendiente_validacion','parcialmente_pagada','pagada','anulada','exenta','vencida');
 create table socios(id uuid primary key,club_id uuid,perfil_id uuid,nombre text,apellidos text,estado text);
 create table tutores_socios(id uuid default gen_random_uuid(),club_id uuid,socio_id uuid,tutor_perfil_id uuid,contacto_principal boolean);
 create table socio_disciplinas(club_id uuid,socio_id uuid,grupo_id uuid,disciplina_id uuid,activa boolean);
 create table cuotas(id uuid primary key default gen_random_uuid(),club_id uuid,socio_id uuid,tarifa_id uuid,periodo date,concepto text,concepto_publico text,importe numeric(10,2) check(importe>=0),vencimiento date,estado estado_cuota default 'pendiente',origen text,categoria_financiera text,generado_automaticamente boolean,lote_cargo_id uuid,snapshot_regla jsonb,pago_comunicado_en timestamptz,avisos_pausados boolean,motivo_pausa_avisos text,avisos_pausados_hasta date,avisos_pausados_por uuid,avisos_pausados_en timestamptz,actualizado_en timestamptz,unique(club_id,socio_id,periodo,concepto));
 create table pagos(id uuid primary key default gen_random_uuid(),club_id uuid,cuota_id uuid,socio_id uuid,importe numeric(10,2) check(importe>0),fecha date,metodo text,referencia text,justificante_url text,estado_validacion text,observaciones text,comunicado_por uuid,comunicado_en timestamptz,validado_por uuid,validado_en timestamptz,motivo_rechazo text,rechazado_en timestamptz);
 create table notificaciones(club_id uuid,perfil_id uuid,rol_destino rol_club,clave text,tipo text,titulo text,cuerpo text,ruta text,datos jsonb,creada_por uuid);
 create unique index np on notificaciones(club_id,perfil_id,clave) where clave is not null and perfil_id is not null;
 create unique index nr on notificaciones(club_id,rol_destino,clave) where clave is not null and rol_destino is not null;
 create function tiene_rol_club(uuid,variadic text[]) returns boolean language sql as $$select auth.uid()='${admin}'::uuid and $1='${club}'::uuid$$;
 insert into socios values('${student}','${club}',null,'QA','Student','activo');
 insert into tutores_socios(club_id,socio_id,tutor_perfil_id,contacto_principal) values('${club}','${student}','${parent}',true);`);
 await db.exec(readFileSync(new URL('./fixtures/club-multi-fees-live-fix13.sql',import.meta.url),'utf8'));
 await as(admin);
 for(const [concepto,importe] of [['Karate',50],['Kickboxing',70],['Licencia',15]]){
  await db.query('select private.finance_create_manual_charge_v144($1,$2,$3)',[JSON.stringify({categoria:'cuota',concepto,importe,periodo:'2026-10-01',vencimiento:'2026-10-15',destinatarios:[{tipo:'socio',id:student},{tipo:'socio',id:student}]}),club,admin]);
 }
 const fees=(await db.query('select id,concepto_publico from cuotas order by importe')).rows;
 ok('three separate charges for one student and period',fees.length===3);
 ok('no duplicate recipient inside batch',(await db.query('select count(*)::int n from cuotas where socio_id=$1',[student])).rows[0].n===3);
 const karate=fees.find(x=>x.concepto_publico==='Karate').id,kick=fees.find(x=>x.concepto_publico==='Kickboxing').id;
 await as(parent);const p1=await communicate(karate,20);
 await reject(()=>communicate(karate,10),/pendiente de validar/);
 await as(admin);await validate(p1);ok('partial payment total',Number(await amount(karate))===20);
 ok('partial status',(await db.query('select estado from cuotas where id=$1',[karate])).rows[0].estado==='parcialmente_pagada');
 await validate(p1);ok('revalidation does not double payment',Number(await amount(karate))===20);
 await as(parent);await reject(()=>communicate(karate,31),/saldo pendiente/);
 const p2=await communicate(karate,30);await as(admin);await validate(p2);
 ok('two successive payments settle one fee',Number(await amount(karate))===50);
 ok('fully paid status',(await db.query('select estado from cuotas where id=$1',[karate])).rows[0].estado==='pagada');
 await as(parent);await reject(()=>communicate(karate,1),/ya no admite/);
 for(const value of [10,20,40]){await as(parent);const p=await communicate(kick,value);await as(admin);await validate(p);}
 ok('three payments independently settle second fee',Number(await amount(kick))===70);
 ok('other fee remains unpaid',Number(await amount(fees.find(x=>x.concepto_publico==='Licencia').id))===0);
 ok('five payment records retained',(await db.query("select count(*)::int n from pagos where estado_validacion='validado'")).rows[0].n===5);
 await as(id(99));await reject(()=>communicate(fees[0].id,1),/Sin acceso/);await reject(()=>validate(p1),/Sin permisos/);
 console.log(`PASS ${passed}/${passed} multiple student charges and payments; isolated database, live function definitions`);
}catch(e){console.error(e.message,e.code);process.exitCode=1;}finally{await db.close();}
