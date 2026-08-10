export const PERMISSIONS = Object.freeze({
  discipline:['direccion','coordinacion','secretaria'], grade:['direccion','coordinacion','secretaria','monitor'], group:['direccion','coordinacion','secretaria'],
  member:['direccion','coordinacion','secretaria'], enrollmentManage:['direccion','coordinacion','secretaria'], graduation:['direccion','coordinacion','secretaria','monitor'],
  tariff:['direccion','coordinacion','economia'], material:['direccion','coordinacion','secretaria','economia'], materialManage:['direccion','coordinacion','secretaria','economia'],
  communication:['direccion','coordinacion','secretaria','comunicacion'], session:['direccion','coordinacion','secretaria','monitor'], attendance:['direccion','coordinacion','secretaria','monitor'],
  checkin:['direccion','coordinacion','secretaria','monitor'], tracking:['direccion','coordinacion','secretaria','monitor'], document:['direccion','coordinacion','secretaria'],
  paymentAdmin:['direccion','coordinacion','secretaria','economia'], feeGenerate:['direccion','coordinacion','economia'], reminders:['direccion','coordinacion','secretaria','economia'],
  invite:['direccion'], clubConfig:['direccion','coordinacion','secretaria','economia','comunicacion'], certification:['direccion']
});
export const has = (session, permission) => {
  const allowed=PERMISSIONS[permission]||[]; const roles=session?.roles?.length?session.roles:[session?.rol].filter(Boolean);
  return roles.some(r=>allowed.includes(r));
};
export const ROLE_LABELS=Object.freeze({direccion:'Gestor de la app',coordinacion:'Coordinación',secretaria:'Secretaría',economia:'Economía / Tesorería',comunicacion:'Comunicación',monitor:'Monitor',familia:'Familia',alumno:'Alumno'});
export const roleLabel=(role)=>ROLE_LABELS[role]||role||'';
export const rolesLabel = (roles=[]) => [...new Set(roles)].map(roleLabel).join(', ');
