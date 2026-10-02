import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=p=>readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const bytes=p=>readFileSync(new URL(`../${p}`,import.meta.url));
const sha=b=>createHash('sha256').update(b).digest('hex');
let pass=0;const test=(name,fn)=>{fn();pass++;console.log(`✓ ${name}`)};
const gateway=read('web/js/modules/gateway.js');
const publicProfile=read('web/js/modules/public-profile.js');
const managed=read('web/js/modules/managed-profile-hub.js');
const owner=read('web/js/modules/platform-admin.js');
const repos=read('web/js/core/repositories.js');
const m302=read('supabase/migrations/302_kombax_pilot_social_read_and_member_interest_r117.sql');
const m303=read('supabase/migrations/303_kombax_pilot_open_registration_no_code_r117.sql');
const m304=read('supabase/migrations/304_kombax_public_profiles_member_spectator_r117.sql');

test('Pilot Club registration no longer asks for an invitation code',()=>{
  assert.ok(!gateway.includes("name:'pilot_code'"));
  assert.ok(gateway.includes('No necesitas código de invitación'));
  assert.ok(owner.includes('Alta directa · sin código de invitación'));
  assert.ok(!owner.includes('data-kx-pilot-invite'));
  assert.ok(m303.includes("'invite_code_required',false"));
  assert.ok(m303.includes('PILOT_INVITE_CODES_DISABLED'));
  assert.ok(!m303.includes('KOMBAX_PILOT_INVITE_CODE_REQUIRED'));
});

test('Member/Practitioner public profile exists independently from Club membership',()=>{
  assert.ok(gateway.includes('Crear / abrir mi perfil público'));
  assert.ok(gateway.includes('No necesitas pertenecer a un club'));
  assert.ok(repos.includes('app_kombax_member_public_profile_r117'));
  assert.ok(m304.includes('alter column club_origen_id drop not null'));
  assert.ok(m304.includes("'membership_confirmed',false"));
  assert.ok(m304.includes("'album_enabled',true"));
});

test('Member album management is separated from feed publishing',()=>{
  assert.ok(publicProfile.includes('Las fotos y vídeos del álbum no se publican automáticamente en el feed Social'));
  assert.ok(publicProfile.includes("const canPublish=p.publication_enabled===true"));
  assert.ok(m304.includes('app_kombax_social_puede_gestionar_perfil_publico_r117'));
  assert.ok(m304.includes("mc.rol='alumno'"));
  assert.ok(m304.includes('KOMBAX_POST_NOT_ALLOWED') || read('supabase/migrations/301_kombax_pilot_onboarding_member_social_gate_r115.sql').includes("mc.rol='alumno'"));
});

test('Spectator has public profile/avatar/banner but no album or feed publishing',()=>{
  assert.ok(gateway.includes('Perfil público básico, sin álbum ni publicación Social.'));
  assert.ok(gateway.includes('no dispone de álbum ni publica en el feed Social'));
  assert.ok(publicProfile.includes("type!=='espectador'"));
  assert.ok(managed.includes('Espectador no dispone de álbum ni publica en el feed Social'));
  assert.ok(m304.includes('KOMBAX_SPECTATOR_ALBUM_DISABLED'));
  assert.ok(m304.includes("'album_enabled',case when v_type='espectador' then false"));
});

test('Managed Spectator public profile is actionable',()=>{
  assert.ok(managed.includes("'public_profile','content_center'"));
  assert.ok(managed.includes("if(mod==='public_profile')"));
  assert.ok(managed.includes('openKombaxPublicProfile'));
});

test('Authenticated Social reading stays independent from publishing',()=>{
  assert.ok(m302.includes('app_kombax_social_read_access_r117'));
  assert.ok(m302.includes('auth.uid() is not null'));
  assert.ok(m304.includes('app_kombax_social_puede_actuar_v051'));
});

test('Web, Netlify dist and Android bundled assets are byte-identical for changed files',()=>{
  for(const f of ['js/core/repositories.js','js/modules/gateway.js','js/modules/public-profile.js','js/modules/managed-profile-hub.js','js/modules/platform-admin.js','js/i18n/r110-pilot-copy.js']){
    assert.equal(sha(bytes(`web/${f}`)),sha(bytes(`dist/${f}`)),`web/dist drift: ${f}`);
    assert.equal(sha(bytes(`web/${f}`)),sha(bytes(`android/app/src/main/assets/www/${f}`)),`web/android drift: ${f}`);
  }
});

console.log(`R117 pilot hotfix profiles/open-registration QA: ${pass}/7 PASS`);
