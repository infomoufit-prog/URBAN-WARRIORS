// Supabase R263 uses this selector only as a request sentinel. It is never a federation identity.
export const INTERNAL_LICENSE_FEDERATION_ID='00000000-0000-4000-8000-000000000263';
export function isInternalClubLicense(license){
  return license?.federation_profile_id==null || String(license.federation_profile_id)===INTERNAL_LICENSE_FEDERATION_ID;
}
export function publicClubFederations(relations=[]){
  return (relations||[]).filter(row=>!isInternalClubLicense(row));
}
export function federationLicenseLabel(license){
  return isInternalClubLicense(license)?'Registro interno · Sin federación':String(license?.federation_name||'Federación no identificada');
}
