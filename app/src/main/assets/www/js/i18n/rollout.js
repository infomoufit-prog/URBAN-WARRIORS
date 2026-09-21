import { SUPPORTED_LOCALES, ENABLED_LOCALES } from './locale-metadata.js';

export const LOCALE_ROLLOUT = Object.freeze({
  es:{supported:true,enabled:true,gate:'validated_for_pilot'},
  en:{supported:true,enabled:true,gate:'validated_for_pilot'},
  fr:{supported:true,enabled:true,gate:'catalog_legacy_public_system_qa_passed_manual_authenticated_visual_e2e_recommended'},
  pt:{supported:true,enabled:true,gate:'catalog_legacy_public_system_qa_passed_manual_authenticated_visual_e2e_recommended'},
  it:{supported:true,enabled:true,gate:'catalog_legacy_public_system_qa_passed_manual_authenticated_visual_e2e_recommended'},
  de:{supported:true,enabled:true,gate:'catalog_legacy_public_system_qa_passed_manual_authenticated_visual_e2e_recommended'},
  th:{supported:true,enabled:true,gate:'catalog_legacy_public_system_qa_passed_manual_authenticated_visual_e2e_recommended'},
  fil:{supported:true,enabled:true,gate:'catalog_legacy_public_system_qa_passed_manual_authenticated_visual_e2e_recommended'}
});

export function localeRolloutStatus(locale){return LOCALE_ROLLOUT[locale]||null;}
export function validateRolloutConfig(){
  const supported=Object.entries(LOCALE_ROLLOUT).filter(([,v])=>v.supported).map(([k])=>k);
  const enabled=Object.entries(LOCALE_ROLLOUT).filter(([,v])=>v.enabled).map(([k])=>k);
  return {supported_matches:JSON.stringify(supported)===JSON.stringify(SUPPORTED_LOCALES),enabled_matches:JSON.stringify(enabled)===JSON.stringify(ENABLED_LOCALES)};
}
