// Account access is independent from the active tenant or Social publishing identity.
export function accountWorkspaceTargets({profiles=[],clubs=[],settings=[]}={}){
  const prefs=new Map(settings.map(x=>[String(x.profile_id),x]));
  const direct=profiles.filter(p=>!prefs.get(String(p.id))?.archived&&p.estado!=='suspendido'&&p.workflow_estado!=='suspended')
    .map(p=>({key:`profile:${p.id}`,kind:'profile',id:p.id,type:p.tipo,name:p.nombre_publico,profile:p}));
  const unique=new Map();
  for(const c of clubs){const id=c.club_id||c.id,club=c.club||c,slug=club.slug||c.club_slug;if(id&&slug&&!unique.has(String(id)))unique.set(String(id),{key:`club:${id}`,kind:'club',id,type:'club',name:club.nombre||c.club_nombre,slug});}
  return [...direct,...unique.values()];
}
export function automaticWorkspaceTarget(targets,{pendingType='',applications=[],legalRequired=false,supportMode=false}={}){
  if(pendingType||legalRequired||supportMode||applications.some(a=>['submitted','under_review','needs_information'].includes(a.estado)))return null;
  return targets.length===1?targets[0]:null;
}
export function accountEntryDestination(targets,{destination='direct',...guards}={}){
  if(destination==='account')return {kind:'account'};
  const target=automaticWorkspaceTarget(targets,guards);
  if(target)return {kind:'workspace',target};
  if(guards.pendingType||guards.legalRequired||guards.supportMode||guards.applications?.some(a=>['submitted','under_review','needs_information'].includes(a.estado)))return {kind:'account'};
  return {kind:targets.length?'select':'explore'};
}
