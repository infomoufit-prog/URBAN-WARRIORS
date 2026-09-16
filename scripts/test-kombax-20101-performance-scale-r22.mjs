import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const read=p=>fs.readFileSync(root+p,'utf8');
const events=read('web/js/modules/kombax-events.js');
const repos=read('web/js/core/repositories.js');
const framing=read('web/js/ui/media-framing.js');
const css=read('web/css/kombax-events.css');
const sql=['189_kombax_events_performance_scale_fightcard_media_20101_r22.sql','190_kombax_events_bundle_roles_20101_r22.sql','191_kombax_events_keyset_asset_reuse_20101_r22.sql'].map(x=>read(`supabase/migrations/${x}`)).join('\n');
const checks=[
 ['first viewport=24',events.includes('EVENT_DISCOVERY_PAGE_SIZE=24')&&repos.includes("limit=24")],
 ['no 100+120 initial merge',!events.includes("repos.kombaxEvents.live({limit:120}")&&!events.includes("repos.kombaxEvents.list({limit:100}")],
 ['no auto installer on render',!events.includes('renderList();void maybeAutoInstallDemoAlbum()')],
 ['detail cache',events.includes('EVENT_DETAIL_CACHE_MS=60000')],
 ['lazy media observer',events.includes('IntersectionObserver')&&(()=>{const m=events.match(/rootMargin:'(\d+)px 0px'/);return Number(m?.[1]||0)>=280;})()],
 ['main before undercard',events.includes("${mainEventFeature(heroEvent,fights)}<section id=\"kx-event-fight-card\"")],
 ['undercard excludes main',events.includes("String(x.id)!==String(main?.id||'')")],
 ['co-main UI',events.includes('Co-Main Event / combate coestelar')&&events.includes('CO-MAIN EVENT')],
 ['30 fights UI',events.includes('/30 combates')],
 ['30 album UI and arithmetic',events.includes('/ 30 fotos')&&events.includes('photosLeft=Math.max(0,30-photosUsed)')],
 ['bundle reader',repos.includes('app_kombax_evento_bundle_v189')],
 ['R22 mutator v191 first',repos.indexOf('app_kombax_eventos_mutate_v191')<repos.indexOf('app_kombax_eventos_mutate_v189')],
 ['backend 30 photos',sql.includes('EVENT_PHOTO_LIMIT_REACHED')&&sql.includes('   30,')],
 ['backend 30 fights',sql.includes('EVENT_FIGHT_LIMIT_REACHED')&&sql.includes('if v_count>=30')],
 ['co-main backend',sql.includes('co_estelar boolean')&&sql.includes('uq_kombax_evento_one_co_main_r22')],
 ['discovery index',sql.includes('idx_kombax_eventos_publicos_discovery_r22')],
 ['stable non-black placeholder',css.includes('R22 · Performance / Fight Card hierarchy')&&css.includes('linear-gradient(135deg,#151923')],
 ['keyset RPC',sql.includes('app_kombax_eventos_publicos_page_v191')&&sql.includes('p_cursor_bucket')&&sql.includes('next_cursor')],
 ['frontend keyset append',events.includes('discoveryCursor')&&events.includes('listPage')&&events.includes('loadDiscovery({append:true})')],
 ['server-side filters',events.includes('function discoveryRequest()')&&repos.includes('p_phase:phase||null')],
 ['bounded page size',sql.includes('least(48,greatest(1,coalesce(p_limit,24)))')],
 ['reference photo type',sql.includes("'foto_referencia'")&&sql.includes('source_kind')&&sql.includes('source_id')],
 ['reference does not duplicate binary',sql.includes("storage_path,external_url")&&sql.includes("'foto_referencia',null,v_url")],
 ['reference unique active',sql.includes('uq_kombax_evento_media_reference_r22')],
 ['reference counts logical album quota',sql.includes("m.tipo in ('foto','foto_referencia')")],
 ['album reuse UI',events.includes('REUTILIZAR SIN DUPLICAR')&&events.includes('data-kx-reuse-asset')],
 ['participant edit can add album',events.includes("name:'add_to_album'")&&events.includes("source_kind:'participant'")],
 ['poster/banner edit can add album',events.includes("name:'cartel_album'")&&events.includes("name:'banner_album'")],
 ['framing editor secondary action',framing.includes('secondaryActionLabel')&&framing.includes('data-kx-frame-secondary')],
 ['asset reuse responsive UI',css.includes('.kx-media-reuse-panel')&&css.includes('.kx-media-reuse-grid')]
];
let ok=0;for(const [name,pass] of checks){console.log(`${pass?'PASS':'FAIL'} ${name}`);if(pass)ok++;}
console.log(`R22 ${ok}/${checks.length}`);if(ok!==checks.length)process.exit(1);
