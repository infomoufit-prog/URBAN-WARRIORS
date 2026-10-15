// Presentation grouping never creates permission or changes historical actor IDs.
export const identityGroupId=p=>String(p?.canonical_social_id||p?.id||'');
export function identityChoices(rows=[],preferredId=''){
  const groups=new Map();
  for(const row of rows){const key=identityGroupId(row);if(!key)continue;const group=groups.get(key)||[];group.push(row);groups.set(key,group);}
  return [...groups.values()].map(group=>group.find(p=>String(p.id)===String(preferredId))||group.find(p=>String(p.id)===identityGroupId(p))||group[0]);
}
export function resolveIdentity(rows=[],{storedId='',clubId=null,role=''}={}){
  const saved=rows.find(p=>String(p.id)===String(storedId));if(saved)return saved;
  if(storedId){const alias=rows.find(p=>(p.personal_aliases||[]).some(id=>String(id)===String(storedId)));if(alias)return alias;}
  if(clubId&&['direccion','coordinacion'].includes(role)){
    const club=rows.find(p=>p.sujeto_tipo==='club'&&String(p.club_id)===String(clubId));if(club)return club;
  }
  // A regular member defaults to their person, never to an unrelated organization.
  return identityChoices(rows).find(p=>p.is_personal===true||p.sujeto_tipo==='miembro')||rows[0]||null;
}
export function publicationIdentity(rows=[],selectedId=''){
  const selected=rows.find(p=>String(p.id)===String(selectedId));
  if(!selected)return null;
  if(selected.publication_enabled===true&&selected.perfil_tipo!=='espectador')return selected;
  // An authorized facet of the same person is acceptable; a different entity is not.
  if(selected.is_personal===true)return rows.find(p=>identityGroupId(p)===identityGroupId(selected)&&p.publication_enabled===true&&p.perfil_tipo!=='espectador')||null;
  return null;
}
export function combineIdentityRecords(records=[],limit=Infinity){
  const map=new Map();for(const row of records){if(row?.id&&!map.has(String(row.id)))map.set(String(row.id),row);}
  return [...map.values()].sort((a,b)=>String(b.creado_en||'').localeCompare(String(a.creado_en||''))||String(b.id).localeCompare(String(a.id))).slice(0,limit);
}

// Activation belongs to the selected actor, not to an unrelated personal account status.
export function identityIsActive(profile,status={}){
  if(!profile?.id)return false;
  if(profile.profile_state)return ['activo','limitado'].includes(profile.profile_state);
  return status.social_profile_id===profile.id&&status.status==='activa';
}
