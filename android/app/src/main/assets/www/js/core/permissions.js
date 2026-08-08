export const PERMISSIONS = Object.freeze({
  discipline:['direccion','secretaria'], grade:['direccion','secretaria','monitor'], group:['direccion','secretaria'],
  member:['direccion','secretaria'], enrollmentManage:['direccion','secretaria'], graduation:['direccion','secretaria','monitor'],
  tariff:['direccion','economia'], material:['direccion','secretaria','economia'], materialManage:['direccion','secretaria','economia'],
  communication:['direccion','comunicacion'], session:['direccion','secretaria','monitor'], attendance:['direccion','secretaria','monitor'],
  checkin:['direccion','secretaria','monitor'], tracking:['direccion','secretaria','monitor'], document:['direccion','secretaria'],
  paymentAdmin:['direccion','secretaria','economia'], feeGenerate:['direccion','economia'], reminders:['direccion','secretaria','economia'],
  invite:['direccion'], clubConfig:['direccion','secretaria','economia','comunicacion'], certification:['direccion']
});
export const has = (session, permission) => {
  const allowed=PERMISSIONS[permission]||[]; const roles=session?.roles?.length?session.roles:[session?.rol].filter(Boolean);
  return roles.some(r=>allowed.includes(r));
};
export const rolesLabel = (roles=[]) => roles.map(r=>({direccion:'Dirección',secretaria:'Secretaría',economia:'Economía',comunicacion:'Comunicación',monitor:'Monitor',familia:'Familia',alumno:'Alumno'}[r]||r)).join(', ');
