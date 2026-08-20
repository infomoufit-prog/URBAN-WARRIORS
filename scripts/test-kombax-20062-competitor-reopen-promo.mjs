import {readFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url);const read=p=>readFile(new URL(p,root),'utf8');
const [gateway,social,showcase,css,cfg,html,sw,gradle,mutations,validation,continuity,guards]=await Promise.all([
  read('web/js/modules/gateway.js'),read('web/js/modules/kombax-social.js'),read('web/js/modules/showcase.js'),read('web/css/app.css'),read('web/config.js'),read('web/index.html'),read('web/service-worker.js'),read('android/app/build.gradle'),
  read('supabase/migrations/077_kombax_verified_profiles_mutations_20044.sql'),read('supabase/migrations/072_kombax_verified_profiles_validation_20044.sql'),read('supabase/migrations/073_kombax_competitor_identity_continuity_20044.sql'),read('supabase/migrations/074_kombax_verified_profiles_social_guards_20044.sql')
]);
const ok=(v,m)=>{if(!v)throw new Error(`20062: ${m}`);console.log('OK '+m)};
const competitorBlock=gateway.match(/\{id:'competidor'[\s\S]*?benefits:\[[^\]]+\]\}/)?.[0]||'';
ok(competitorBlock&&!/disabled:true/.test(competitorBlock),'Competidor vuelve a estar disponible en selector de identidad');
ok(gateway.includes("['competidor','marca','federacion'].includes(pendingType)"),'alta Competidor continúa tras autenticación');
ok(gateway.includes('Club, Competidor, Marca o Federación')&&gateway.includes('Competidor ya admite solicitud y verificación KOMBAX'),'copy público refleja reapertura de Competidor');
ok(gateway.includes('Continuidad con mi perfil de Miembro')&&gateway.includes('Competidor independiente'),'Competidor conserva alta independiente y continuidad Miembro');
ok(mutations.includes("v_type not in ('competidor','marca','federacion')")&&mutations.includes('KOMBAX_COMPETITOR_ALREADY_EXISTS')&&mutations.includes('KOMBAX_COMPETITOR_OWNER_ONLY'),'backend mantiene unicidad y ownership de Competidor');
ok(validation.includes("v_req.tipo='competidor'")&&/16/.test(validation),'validación canónica Competidor conserva control de edad');
ok(continuity.includes('Upgrade reversible Miembro ↔ Competidor')&&continuity.includes('app_kombax_social_switch_competitor_v072'),'continuidad Social Miembro↔Competidor sigue preservada');
ok(guards.includes("d.tipo='competidor'")&&guards.includes('fecha_nacimiento_verificada'),'guardas Social Competidor permanecen activas');
const socialPromo=social.match(/function competitorFoundersPromo\(\)[\s\S]*?\n\}/)?.[0]||'';
const clubPromo=showcase.match(/function clubFoundersPromo\(\)[\s\S]*?\n\}/)?.[0]||'';
ok(socialPromo.includes('COMBAT SOCIAL · LANZAMIENTO')&&socialPromo.includes('PRIMEROS 20 · COMPETIDORES FUNDADORES')&&socialPromo.includes('ventaja especial de lanzamiento'),'Combat Social muestra campaña primeros 20 competidores');
ok(clubPromo.includes('KOMBAX SHOWCASE · LANZAMIENTO')&&clubPromo.includes('PRIMEROS 20 · CLUBES FUNDADORES')&&clubPromo.includes('ventaja especial de lanzamiento'),'Showcase muestra campaña primeros 20 clubes');
ok(!/(€|descuento|porcentaje|\bprecio\b|%)/i.test(socialPromo+clubPromo),'campañas no anuncian precio, descuento ni porcentaje concreto');
ok(social.includes('${competitorFoundersPromo()}')&&showcase.includes('${clubFoundersPromo()}'),'promociones están insertadas en feed Social y catálogo Showcase');
ok(css.includes('.kx-founders-promo')&&css.includes('.kx-founders-promo-mark'),'promoción tiene tratamiento responsive compartido');
const build=Number(cfg.match(/build:\s*(\d+)/)?.[1]);const android=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]);const swBuild=Number(sw.match(/rc13-(\d+)/)?.[1]);const refs=[...html.matchAll(/\?v=(\d+)/g)].map(x=>Number(x[1]));
ok(build===20062&&android===build&&swBuild===build&&refs.length>0&&refs.every(v=>v===build),'web/PWA/Android alineados en build 20062');
console.log('KOMBAX BUILD 20062 · COMPETITOR REOPEN + FOUNDERS PROMO: PASS');
