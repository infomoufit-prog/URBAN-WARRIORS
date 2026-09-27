import assert from 'node:assert/strict';
import {accountProfilePolicy,canRequestAccountProfile} from '../web/js/core/account-profile-policy.js';

const free=accountProfilePolicy();
assert.deepEqual(free.allowed,['club','competidor','marca','federacion','profesional','media']);

for(const type of ['club','marca','federacion','profesional','media','competidor']){
  const policy=accountProfilePolicy({profiles:[{tipo:type}]});
  assert.equal(policy.kind,type);
  assert.equal(policy.canCreate,false);
  assert.equal(canRequestAccountProfile(type==='club'?'marca':'club',policy),false);
}

const member=accountProfilePolicy({memberProfiles:[{id:'member-1'}]});
assert.deepEqual(member.allowed,['competidor']);
assert.equal(canRequestAccountProfile('club',member),false);
const memberBeforeSocial=accountProfilePolicy({memberships:[{modo:'alumno',estado:'activo'}]});
assert.equal(memberBeforeSocial.kind,'miembro');
assert.deepEqual(memberBeforeSocial.allowed,['competidor']);
assert.equal(canRequestAccountProfile('marca',memberBeforeSocial),false);
assert.equal(accountProfilePolicy({memberships:[{modo:'tutor',estado:'activo'}]}).kind,'new');
assert.equal(accountProfilePolicy({memberProfiles:[{id:'member-1'}],profiles:[{tipo:'competidor'}]}).canCreate,false);
assert.equal(accountProfilePolicy({applications:[{tipo:'club'}]}).kind,'club');
assert.equal(accountProfilePolicy({managedClubs:[{club_id:'club-1'}]}).kind,'club');
assert.equal(accountProfilePolicy({managedClubs:[{club_id:'club-1'}],profiles:[{tipo:'federacion'}]}).kind,'conflict');

console.log('KOMBAX R101 account profile policy: 15 scenarios OK');
