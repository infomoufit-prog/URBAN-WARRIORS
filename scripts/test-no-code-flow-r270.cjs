const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const src=fs.readFileSync('web/js/modules/gateway.js','utf8');const start=src.indexOf('async function openMemberClubLink('),end=src.indexOf('export async function renderClubDirectory(',start);assert(start>=0&&end>start);
(async()=>{let authenticated=true,form,authShown=false,calls=[],active=[],pending=[],claim,errors=[];
const ctx={globalAuthenticated:()=>authenticated,openGlobalAuth:()=>authShown=true,renderClubDirectory:()=>{},toast:()=>{},closeModal:()=>{},setError:e=>errors.push(e.message),openForm:f=>form=f,confirmDialog:(title,text,f)=>claim=f,repos:{kombaxMemberships:{pending:async()=>pending,active:async()=>active,contactClub:async(...a)=>{calls.push(a);return{}},requestClaim:async id=>{calls.push(['claim',id]);return{}}}}};
vm.createContext(ctx);vm.runInContext(src.slice(start,end)+';globalThis.openLink=openMemberClubLink;',ctx);const club={id:'club',nombre:'QA'};
authenticated=false;await ctx.openLink(club,{});assert(authShown&&calls.length===0);
authenticated=true;await ctx.openLink(club,{});assert(form.fields[0].options.map(o=>o.value).join(',')==='member,family');await form.onSubmit({request_kind:'family',mensaje:'Vínculo familiar'});assert.deepEqual(calls[0],['club','Vínculo familiar','family']);
active=[{club_id:'club',estado:'activo',modo:'alumno'}];await ctx.openLink(club,{});assert(form.fields[0].options.length===1&&form.fields[0].options[0].value==='family');await form.onSubmit({request_kind:'member',mensaje:'Tutor'});assert(calls[1][2]==='family');
active=[];pending=[{club_id:'club',socio_id:'existing'}];await ctx.openLink(club,{});await claim();assert.deepEqual(calls[2],['claim','existing']);assert.equal(errors.length,0);
console.log('PASS 5 no-code member/family flow checks with mocked repositories; no real requests sent');
})().catch(e=>{console.error(e);process.exitCode=1});

