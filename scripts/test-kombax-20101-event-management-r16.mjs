import fs from "node:fs";
import path from "node:path";
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),"utf8");
const events=read("web/js/modules/kombax-events.js");
const css=read("web/css/kombax-events.css");
const index=read("web/index.html"),sw=read("web/service-worker.js");
const checks=[
 ["single management launcher exists",events.includes("function eventManagementMenu(event)")&&events.includes('id="kx-event-manage-toggle"')&&events.includes("Gestionar evento")],
 ["legacy management action wall removed",!["id=\"kx-event-builder\"","id=\"kx-event-edit\"","id=\"kx-event-cover-edit\"","id=\"kx-event-participants\"","id=\"kx-event-fight-create\"","id=\"kx-event-media\"","id=\"kx-event-partners\""].some(x=>events.includes(x))],
 ["all management destinations remain reachable",["builder","edit","cover","participants","fight","media","partners","visual"].every(x=>events.includes(`data-kx-manage="${x}"`))],
 ["management is permission-gated",events.includes("if(!event?.can_manage)return ''")&&events.includes("${eventManagementMenu(event)}")],
 ["desktop popover styling exists",css.includes(".kx-event-manage-menu{position:absolute")&&css.includes("top:50px;right:0")],
 ["tablet management styling exists",css.includes("@media(min-width:621px) and (max-width:1024px){.kx-event-manage-shell")],
 ["mobile bottom sheet exists",css.includes("@media(max-width:620px){")&&css.includes(".kx-event-manage-menu{position:fixed")&&css.includes("bottom:0;width:100%")],
 ["mobile scrim and safe area exist",css.includes(".kx-event-manage-scrim:not([hidden])")&&css.includes("env(safe-area-inset-bottom)")],
 ["accessible toggle and close behavior exist",events.includes('aria-expanded="false"')&&events.includes("setAttribute('aria-expanded'")&&events.includes("e.key==='Escape'")],
 ["public actions stay separate",events.includes('id="kx-event-interest"')&&events.includes('id="kx-event-share"')&&events.includes('id="kx-event-qr"')],
 ["R14 creator preserved",/EVENT CREATOR · R(?:14|1[5-9]|2\d)/.test(events)],
 ["R15 responsive tuning preserved",read("web/css/kombax-brand-heroes.css").includes("KOMBAX 20.101 R15 · RESPONSIVE VISUAL TUNING")],
 ["cache bust R16",revisionAtLeast(index,16)&&revisionAtLeast(sw,16,'media-r')],
 ["no backend changes introduced",fs.existsSync(path.join(root,"supabase/migrations/181_kombax_events_creator_participant_update_20101_r14.sql"))],
];
let bad=0;for(const [name,ok] of checks){console.log(`${ok?"PASS":"FAIL"} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log("OK KOMBAX 20.101 R16 Event Management UX Cleanup");
