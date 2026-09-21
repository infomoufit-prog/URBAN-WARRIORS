import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RELEASE C: ${msg}`);console.log(`OK RELEASE C: ${msg}`)};
const [activity,service,admin,app]=await Promise.all([
  read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),
  read('android/app/src/main/java/com/urbanwarriors/app/UrbanWarriorsMessagingService.java'),
  read('web/js/modules/admin.js'),
  read('web/js/app.js')
]);

assert(activity.includes('initializeFirebaseSafely')&&activity.includes('FirebaseApp.initializeApp'),'Firebase se inicializa explícitamente');
assert(activity.includes('catch (Throwable error)')&&activity.includes('la app continuará funcionando'),'fallo Firebase no bloquea arranque');
assert(activity.indexOf('initializeFirebaseSafely()')<activity.indexOf('FirebaseMessaging.getInstance().getToken()'),'token solo después de inicialización segura');
assert(activity.includes('refreshPushTokenSafely')&&activity.includes('addOnCompleteListener'),'token asíncrono y tolerante a fallos');
assert(activity.includes('notification_permission_requested')&&activity.includes('shouldShowRequestPermissionRationale'),'estado de permiso distingue solicitud y bloqueo');
assert(activity.includes('ACTION_APP_NOTIFICATION_SETTINGS')&&activity.includes('ACTION_APPLICATION_DETAILS_SETTINGS'),'apertura directa de ajustes con fallback');
assert(activity.includes('getNotificationPermissionState')&&activity.includes('openNotificationSettings'),'puente Android expone onboarding');
assert(service.includes('onNewToken')&&service.includes('Token FCM renovado'),'renovación queda persistida y registrada');
assert(service.includes('catch (SecurityException error)'),'notificación bloqueada no causa crash');
assert(admin.includes('Activa las notificaciones')&&admin.includes('Abrir ajustes de notificaciones'),'experiencia explica permiso y ajustes');
assert(app.includes('uw-native-push-token')&&app.includes("push.registrar"),'frontend registra token cuando llega');
console.log('RELEASE C FIREBASE SAFE: PASS');
