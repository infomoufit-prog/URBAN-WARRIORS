// A commercial account has one primary identity. A club member may also
// develop a competitor identity without changing the club account they belong to.
const ORGANIZATION_TYPES=new Set(['club','marca','federacion','profesional','media']);

export function accountProfilePolicy({profiles=[],applications=[],managedClubs=[],memberProfiles=[],memberships=[]}={}){
  const types=new Set();
  if(managedClubs.length)types.add('club');
  for(const row of profiles)if(row?.tipo&&row.tipo!=='espectador')types.add(row.tipo);
  for(const row of applications)if(row?.tipo)types.add(row.tipo);
  // A club member exists before Social is activated. Social is optional and
  // must not determine which type of commercial account the email may open.
  const member=memberProfiles.length>0||memberships.some(row=>row?.modo==='alumno'&&row?.estado==='activo');
  const organizations=[...types].filter(type=>ORGANIZATION_TYPES.has(type));
  const conflict=organizations.length>1||(organizations.length>0&&(member||types.has('competidor')));
  if(conflict)return {kind:'conflict',allowed:[],canCreate:false};
  if(organizations.length)return {kind:organizations[0],allowed:[],canCreate:false};
  if(member)return {kind:'miembro',allowed:types.has('competidor')?[]:['competidor'],canCreate:!types.has('competidor')};
  if(types.has('competidor'))return {kind:'competidor',allowed:[],canCreate:false};
  return {kind:'new',allowed:['club','competidor','marca','federacion','profesional','media'],canCreate:true};
}

export function canRequestAccountProfile(type,policy){return Boolean(policy?.allowed?.includes(type));}
