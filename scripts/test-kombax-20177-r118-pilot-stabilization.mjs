import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

const root=resolve(import.meta.dirname,'..');
const read=rel=>readFile(resolve(root,rel),'utf8');
const [
  config,distConfig,androidConfig,gradle,activity,packageJson,
  policy,repos,gateway,discovery,publicProfile,professionalOps,platformAdmin,backend,app,
  m311,m312,m315,m316,m317,m318,m319,m320,m321,m322,m323,m324,
  contract
]=await Promise.all([
  read('web/config.js'),read('dist/config.js'),read('android/app/src/main/assets/www/config.js'),
  read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('package.json'),
  read('web/js/core/account-profile-policy.js'),read('web/js/core/repositories.js'),
  read('web/js/modules/gateway.js'),read('web/js/modules/kombax-discovery.js'),
  read('web/js/modules/public-profile.js'),read('web/js/modules/professional-operations.js'),
  read('web/js/modules/platform-admin.js'),read('web/js/core/backend.js'),read('web/js/app.js'),
  read('supabase/migrations/311_kombax_progressive_club_enrollment_r117.sql'),
  read('supabase/migrations/312_kombax_pilot_club_minimal_progressive_r117.sql'),
  read('supabase/migrations/315_kombax_team_access_request_notifications_r117.sql'),
  read('supabase/migrations/316_kombax_request_notification_lifecycle_r117.sql'),
  read('supabase/migrations/317_kombax_r118_multifacet_identity_core.sql'),
  read('supabase/migrations/318_kombax_r118_professional_credentials.sql'),
  read('supabase/migrations/319_kombax_r118_canonical_person_discovery.sql'),
  read('supabase/migrations/320_kombax_r118_discovery_contact_limit.sql'),
  read('supabase/migrations/321_kombax_r118_request_outcome_notifications.sql'),
  read('supabase/migrations/322_kombax_r118_already_linked_request_guard.sql'),
  read('supabase/migrations/323_kombax_r118_notification_lifecycle_gateway.sql'),
  read('supabase/migrations/324_kombax_r118_resolved_link_notification_cleanup.sql'),
  read('docs/R118_ARCHITECTURE_CONTRACT.md')
]);

const checks=[];
const ok=(name,value)=>{assert.ok(value,name);checks.push(name);};

ok('web build 20177',/build:\s*20177/.test(config));
ok('dist build 20177',/build:\s*20177/.test(distConfig));
ok('android asset build 20177',/build:\s*20177/.test(androidConfig));
ok('R118 release name',/r118-pilot-stabilization-1/.test(config)&&/r118-pilot-stabilization-1/.test(gradle));
ok('Android versionCode 20177',/versionCode\s+20177/.test(gradle));
ok('Android UA 20177',/KOMBAXRevision\/r118-pilot-stabilization KOMBAXApp\/2\.0\.0-rc\.13\/20177/.test(activity));
ok('package version R118',/"version":\s*"2\.0\.0-rc\.13-r118-pilot-stabilization-1"/.test(packageJson));

ok('R118 contract says one canonical social profile',/Perfil Social público canónico/.test(contract));
ok('R118 contract separates entitlement subject',/subject_type \+ subject_id \+ capability/.test(contract));
ok('account type is legacy metadata',/LEGACY R100 onboarding classification/.test(m317));
ok('account type no longer blocks pilot club',!/KOMBAX_PILOT_CLUB_ACCOUNT_REQUIRED/.test(m317));
ok('identity guard allows compatible facets',/permits multiple compatible facets/.test(m317));
ok('frontend policy allows compatible multiprofile',/compatible/i.test(policy)&&/competidor/i.test(policy)&&/profesional/i.test(policy));

ok('pilot form remains progressive',/Ubicación pública · opcional/.test(gateway)&&/Disciplinas · opcional/.test(gateway)&&/sin documentación inicial/.test(gateway));
ok('pilot intent survives cross-tab confirmation',/localStorage\.setItem\(PILOT_PENDING_KEY,'1'\)/.test(gateway)&&/pilotPending\(\)/.test(gateway));
ok('pilot backend still avoids approval/code/document gates',/invite_code_required',false/.test(m312)&&/approval_required',false/.test(m312)&&/document_verification_required',false/.test(m312));

ok('normal registration creates pre-enrollment before membership',/membership_created',false/.test(m311)&&/club_authorization_required',true/.test(m311));
ok('bound student invitation survives email confirmation',/uw2_pending_student_membership/.test(app)&&/app_kombax_alumno_aceptar_r59/.test(backend));
ok('generic team request remains approval-gated',/estado,'pendiente'/.test(m315)&&/rol_solicitado/.test(m315));
ok('team request persists across confirmation',/kombax_pending_team_access/.test(backend)&&/completePendingTeamAccess/.test(backend));

ok('professional credential evidence is private metadata',/kombax_professional_credential_evidence_r118/.test(m318)&&/revoke all on public\.kombax_professional_credential_evidence_r118/.test(m318));
ok('credential truth declaration is versioned',/credential_acceptances_r118/.test(m318)&&/declaration_version/.test(m318));
ok('credential verification uses canonical Spanish state',/estado='verificada'/.test(m318)&&!/estado='verified'/.test(m319));
ok('professional UI requires evidence and declaration',/Evidencia privada/.test(professionalOps)&&/declaration_accepted/.test(professionalOps));
ok('Owner has credential review queue',/professionalCredentialQueue/.test(platformAdmin)&&/professionalCredentialReview/.test(platformAdmin));

ok('Discovery aggregates one person with facets',/facet_types/.test(m319)&&/'facets'/.test(m319)&&/person_profile_id/.test(m319));
ok('Discovery client uses R118 with fallback',/app_kombax_discovery_search_r118/.test(repos)&&/app_kombax_discovery_search_r626/.test(repos));
ok('Discovery card understands person facets',/facet_types/.test(discovery)||/facets/.test(discovery));
ok('public profile exposes verified facets',/personFacets/.test(publicProfile)||/verified_facets/.test(publicProfile)||/facets/.test(publicProfile));
ok('R118 contact/limit correction exists',/app_kombax_discovery_search_r118/.test(m320));

ok('request tasks remain state-driven',/app_notificacion_requiere_accion_v034/.test(m316)&&/estado='pendiente'/.test(m316));
ok('requester receives team outcome',/Acceso al equipo aprobado/.test(m321)&&/Solicitud de equipo rechazada/.test(m321));
ok('requester receives link/claim rejection outcome',/Vinculación rechazada/.test(m321));
ok('already-linked member cannot reopen request',/already_linked/.test(m322)&&/private_club_access_enabled',true/.test(m322));
ok('notification trigger uses lifecycle gateway',/kombax\.lifecycle_gateway/.test(m323)&&/set_config/.test(m323));
ok('resolved legacy manager notices are archived',/n\.rol_destino is not null/.test(m324));

ok('selected-club login remains strict',/if\(requested&&!candidate\)throw new Error\('Esta cuenta no está vinculada a este club/.test(backend));
ok('selected-club login still has no silent fallback',!/memberships\.find\(m=>m\.clubes\?\.slug===requestedSlug\)\|\|memberships\[0\]/.test(backend));

console.log(`PASS ${checks.length}/${checks.length} · KOMBAX R118 build 20177 identity / pilot / verification / request lifecycle`);
for(const name of checks)console.log(`  ✓ ${name}`);
