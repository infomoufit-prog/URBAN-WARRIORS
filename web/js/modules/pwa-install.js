/* KOMBAX R270 — One install experience for every identity and club role.
   A PWA cannot be installed silently: browser install prompt requires a user gesture.
   Native Android is already installed; iOS uses the browser's Add to Home Screen UI. */
let listening=false;
let installPending=null;
let installedInSession=false;

export function classifyPwaEnvironment({navigator:nav,window:win}={navigator:globalThis.navigator,window:globalThis.window}){
  const ua=String(nav?.userAgent||'');
  const androidWrapper=Boolean(win?.UrbanWarriorsNative)||win?.location?.hostname==='appassets.androidplatform.net';
  const standalone=androidWrapper||Boolean(nav?.standalone)||Boolean(win?.matchMedia?.('(display-mode: standalone)')?.matches);
  const ios=/iPad|iPhone|iPod/i.test(ua)||(/Macintosh/i.test(ua)&&Number(nav?.maxTouchPoints||0)>1);
  const android=/Android/i.test(ua);
  const inAppBrowser=/(Instagram|FBAN|FBAV|Line\/|MicroMessenger)/i.test(ua);
  const secure=win?.location?.protocol==='https:'||['localhost','127.0.0.1'].includes(win?.location?.hostname);
  return {androidWrapper,standalone,ios,android,inAppBrowser,secure};
}

export function initPwaInstall(){
  if(listening||typeof window==='undefined')return;
  listening=true;
  window.addEventListener('beforeinstallprompt',event=>{
    event.preventDefault();
    installPending=event;
    window.__uwInstallPrompt=event; // compatibility with the public install route
    window.dispatchEvent(new CustomEvent('kombax:pwa-install-available'));
  });
  window.addEventListener('appinstalled',()=>{
    installedInSession=true;
    installPending=null;
    window.__uwInstallPrompt=null;
    window.dispatchEvent(new CustomEvent('kombax:pwa-installed'));
  });
}

export function pwaInstallState(){
  const platform=classifyPwaEnvironment();
  return {...platform,installed:installedInSession||platform.standalone,canPrompt:Boolean(installPending||window.__uwInstallPrompt)};
}

function manualInstructions(info){
  if(info.androidWrapper)return '<p>Estás usando la aplicación Android de KOMBAX. Ya está instalada en este dispositivo.</p>';
  if(info.standalone)return '<p>KOMBAX ya está instalada y ejecutándose como aplicación. No necesitas instalarla otra vez.</p>';
  if(!info.secure)return '<p>Abre KOMBAX desde <strong>https://kombax.es</strong> para instalarla. La instalación requiere una conexión segura.</p>';
  if(info.inAppBrowser)return '<p>Abre esta página en <strong>Chrome</strong> o <strong>Safari</strong> fuera del navegador integrado de esta aplicación. Después sigue los pasos de instalación.</p>';
  if(info.ios)return '<p>Abre KOMBAX en <strong>Safari</strong>, toca <strong>Compartir</strong> y elige <strong>Añadir a pantalla de inicio</strong>. Confirma con <strong>Añadir</strong>.</p>';
  if(info.android)return '<p>Abre KOMBAX en <strong>Chrome</strong>, toca el menú <strong>⋮</strong> y selecciona <strong>Instalar aplicación</strong> o <strong>Añadir a pantalla de inicio</strong>.</p>';
  return '<p>En Chrome o Edge abre el menú del navegador y selecciona <strong>Instalar KOMBAX</strong> o busca el icono de instalación en la barra de direcciones. En Safari para macOS puedes usar <strong>Archivo → Añadir al Dock</strong>, si está disponible.</p>';
}

export async function openPwaInstallInstructions(){
  const {openDetail}=await import('../ui/components.js');
  const status=pwaInstallState();
  const modal=openDetail({title:'Instalar KOMBAX',subtitle:'La misma cuenta y todos tus perfiles, desde el acceso directo de tu dispositivo.',width:'580px',
    body:`<div class="kx-pwa-install-help"><p><strong>Acceso para todas tus identidades:</strong> miembro, familia, club, competidor, federación, profesional, marca, media y espectador.</p>${manualInstructions(status)}<p class="muted">La instalación de la PWA es gratuita y no cambia tus permisos ni requiere Google Play.</p></div>`,
    actions:'<button type="button" class="btn btn-primary" data-kx-pwa-install-done>Entendido</button>'});
  modal.wrap.querySelector('[data-kx-pwa-install-done]')?.addEventListener('click',modal.close);
  return modal;
}

export async function requestPwaInstall(){
  initPwaInstall();
  const status=pwaInstallState();
  if(status.installed){
    const {toast}=await import('../ui/components.js');
    toast('KOMBAX ya está instalada en este dispositivo.');return {status:'installed'};
  }
  const prompt=installPending||window.__uwInstallPrompt;
  if(prompt&&typeof prompt.prompt==='function'){
    installPending=null;window.__uwInstallPrompt=null;
    try{
      // Call prompt synchronously from the click handler. Do not await imports first:
      // browsers can expire the transient user activation needed to install a PWA.
      const started=prompt.prompt();
      await started;
      const outcome=await prompt.userChoice;
      const {toast}=await import('../ui/components.js');
      if(outcome?.outcome==='accepted'){toast('Instalación aceptada. Sigue las indicaciones del dispositivo.');return {status:'accepted'};}
      toast('Instalación cancelada. Puedes volver a intentarlo desde tu perfil.');
      return {status:'dismissed'};
    }catch(error){console.warn('KOMBAX PWA installation:',error);}
  }
  await openPwaInstallInstructions();
  return {status:'instructions'};
}
