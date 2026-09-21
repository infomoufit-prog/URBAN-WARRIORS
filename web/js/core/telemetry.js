import { backend } from './backend.js';
import { state } from './state.js';

const sent=new Map();
const SECRET_PATTERN=/(access[_ -]?token|refresh[_ -]?token|bearer\s+[a-z0-9._-]+|password|contraseña|eyJ[a-z0-9_-]{10,})/ig;
function safeText(value,max=500){return String(value||'Error no especificado').replace(SECRET_PATTERN,'[REDACTED]').slice(0,max)}
function fingerprint(code,message){return `${code}:${message.slice(0,160)}`}
async function report(code,error,extra={}){
  if(!state.session?.id)return;
  const message=safeText(error?.message||error),key=fingerprint(code,message),now=Date.now();
  if(now-Number(sent.get(key)||0)<5*60*1000)return;
  sent.set(key,now);
  try{
    await backend.globalWriteRpc('app_kombax_client_incident_report_v117',{
      p_build:String(window.UW_CONFIG?.release?.build||'unknown'),p_codigo:code,p_mensaje:message,
      p_contexto:{route:safeText(location.hash||'root',100),online:navigator.onLine,visibility:document.visibilityState,...extra}
    });
  }catch{/* La telemetría nunca debe interrumpir el uso ni generar recursión. */}
}

export function installClientTelemetry(){
  window.addEventListener('error',event=>report('CLIENT.ERROR',event.error||event.message,{source:safeText(event.filename,180),line:Number(event.lineno||0)}));
  window.addEventListener('unhandledrejection',event=>report('CLIENT.REJECTION',event.reason));
}
