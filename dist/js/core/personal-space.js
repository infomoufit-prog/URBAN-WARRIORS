// Personal facets share a canonical Social identity. Organization profiles are separate.
const PERSONAL_TYPES=new Set(['competidor','profesional','espectador']);
export function personalSpaceModel({profiles=[],memberPublicProfile=null}={}){
  const facets=profiles.filter(p=>PERSONAL_TYPES.has(p.tipo));
  const member=Boolean(memberPublicProfile?.id);
  return {
    hasPersonalProfile:member||facets.length>0,
    name:memberPublicProfile?.nombre_publico||facets[0]?.nombre_publico||'',
    socialId:memberPublicProfile?.id||facets.find(p=>p.social_profile_id)?.social_profile_id||null,
    facets:[...new Set([...(member?['miembro']:[]),...facets.map(p=>p.tipo)])],
    memberCanPublish:memberPublicProfile?.membership_confirmed===true&&memberPublicProfile?.publication_enabled===true
  };
}
