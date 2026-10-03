// KOMBAX R118 · Multifacet account policy.
// The Auth account is not a profile type. It may own compatible personal facets
// and manage organizations. This policy only prevents duplicate onboarding of
// the same facet/type; backend permissions remain authoritative.
const PROFILE_TYPES=Object.freeze(['club','competidor','marca','federacion','profesional','media','espectador']);
const CLOSED_APPLICATION_STATES=new Set(['rejected','withdrawn']);

export function accountProfilePolicy({profiles=[],applications=[],managedClubs=[],memberProfiles=[],memberships=[]}={}){
  const existing=new Set((profiles||[]).map(row=>String(row?.tipo||'')).filter(Boolean));
  const pending=new Set((applications||[])
    .filter(row=>row?.tipo&&!CLOSED_APPLICATION_STATES.has(String(row?.estado||'')))
    .map(row=>String(row.tipo)));
  const member=Boolean((memberProfiles||[]).length)||(memberships||[]).some(row=>row?.estado==='activo'&&['alumno','tutor'].includes(String(row?.modo||'')));
  const hasPersonalPublic=member||['competidor','profesional','media','espectador'].some(type=>existing.has(type));

  const allowed=PROFILE_TYPES.filter(type=>{
    if(type==='club')return !(managedClubs||[]).length&&!pending.has('club');
    if(existing.has(type)||pending.has(type))return false;
    if(type==='espectador'&&hasPersonalPublic)return false;
    return true;
  });
  // Member/family is a relationship flow, not a mutually exclusive profile.
  allowed.push('miembro_familia');

  return {
    kind:'multifacet',
    allowed:[...new Set(allowed)],
    existing:[...existing],
    pending:[...pending],
    member,
    manages_club:Boolean((managedClubs||[]).length),
    canCreate:allowed.length>0
  };
}

export function canRequestAccountProfile(type,policy){
  if(!policy)return true;
  return Boolean(policy.allowed?.includes(String(type||'')));
}
