import { t } from '../i18n/index.js';
export const PERMISSIONS = Object.freeze({
  discipline:['direccion','coordinacion','secretaria'], grade:['direccion','coordinacion','secretaria','monitor'], group:['direccion','coordinacion','secretaria'],
  member:['direccion','coordinacion','secretaria'], enrollmentManage:['direccion','coordinacion','secretaria'], graduation:['direccion','coordinacion','secretaria','monitor'],
  tariff:['direccion','coordinacion','economia'], material:['direccion','coordinacion','secretaria','economia'], materialManage:['direccion','coordinacion','secretaria','economia'],
  communication:['direccion','coordinacion','secretaria','comunicacion'], session:['direccion','coordinacion','secretaria','monitor'], attendance:['direccion','coordinacion','secretaria','monitor'],
  checkin:['direccion','coordinacion','secretaria','monitor'], tracking:['direccion','coordinacion','secretaria','monitor'], document:['direccion','coordinacion','secretaria'],
  paymentAdmin:['direccion','coordinacion','secretaria','economia'], feeGenerate:['direccion','coordinacion','economia'], reminders:['direccion','coordinacion','secretaria','economia'],
  invite:['direccion'], clubConfig:['direccion','coordinacion','secretaria','economia','comunicacion'], eventManage:['direccion','coordinacion','secretaria','monitor'], certification:['direccion']
});
export const has = (session, permission) => {
  const allowed=PERMISSIONS[permission]||[]; const roles=session?.roles?.length?session.roles:[session?.rol].filter(Boolean);
  return roles.some(r=>allowed.includes(r));
};
export const ROLE_LABELS=Object.freeze({direccion:'admin.roles.direction',coordinacion:'admin.roles.coordination',secretaria:'admin.roles.secretariat',economia:'admin.roles.treasury',comunicacion:'admin.roles.communications',monitor:'admin.roles.coach',familia:'admin.roles.family',alumno:'admin.roles.student'});
export const roleLabel=(role)=>ROLE_LABELS[role]?t(ROLE_LABELS[role]):role||'';
export const rolesLabel = (roles=[]) => [...new Set(roles)].map(roleLabel).join(', ');
