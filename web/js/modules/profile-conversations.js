import { repos } from '../core/repositories.js';
import { setActiveIdentity } from '../core/identity-context.js';
import { setError, setMainHtml } from '../ui/components.js';
import { renderKombaxConversations } from './kombax-social.js';
import { renderKombaxAssistHome, renderKombaxMigrationsHome } from './customer-operations.js';

// Re-read the managed identity on every channel change, including after revocation.
export async function renderProfileConversations(profileId,{channel='social',onBack}={}){
  try{
    const workspace=await repos.kombaxProfiles.workspace(profileId);
    const profile=workspace?.profile;
    if(profile?.id!==profileId||!['competidor','profesional','marca','federacion'].includes(profile.tipo))throw new Error('El espacio de conversaciones no está disponible.');
    const open=next=>renderProfileConversations(profileId,{channel:next,onBack});
    const context={profileId:profile.id,profileType:profile.tipo,profileName:profile.nombre_publico,
      socialId:profile.social_profile_id,tenantRef:`profile:${profile.id}`,onBack,
      onSocial:()=>open('social'),onShowcase:()=>open('showcase'),
      onAssist:()=>open('assist'),onMigrations:()=>open('migrations')};
    if(context.socialId)setActiveIdentity(context.socialId);
    if(channel==='assist')return await renderKombaxAssistHome(context);
    if(channel==='migrations')return await renderKombaxMigrationsHome(context);
    return await renderKombaxConversations({context,channel:channel==='showcase'?'showcase':'social'});
  }catch(error){setMainHtml('<div class="empty-card">No se ha podido abrir este espacio de conversaciones. Vuelve a tu espacio e inténtalo de nuevo.</div>');setError(error);}
}
