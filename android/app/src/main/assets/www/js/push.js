(function () {
  'use strict';

  const VERSION = '12.17.0';
  let messaging = null;
  let firebaseApp = null;

  function configured() {
    const push = window.UW_CONFIG?.push;
    const firebase = push?.firebase || {};
    return Boolean(push?.enabled && push?.vapidKey && firebase.apiKey && firebase.projectId && firebase.messagingSenderId && firebase.appId);
  }

  async function setup() {
    if (!configured()) throw new Error('Firebase Push todavía no está configurado.');
    if (messaging) return messaging;
    const [{ initializeApp }, { getMessaging, isSupported, onMessage }] = await Promise.all([
      import(`https://www.gstatic.com/firebasejs/${VERSION}/firebase-app.js`),
      import(`https://www.gstatic.com/firebasejs/${VERSION}/firebase-messaging.js`)
    ]);
    if (!(await isSupported())) throw new Error('Este navegador no admite Firebase Cloud Messaging.');
    firebaseApp = initializeApp(window.UW_CONFIG.push.firebase);
    messaging = getMessaging(firebaseApp);
    onMessage(messaging, (payload) => {
      const notification = payload.notification || {};
      if (Notification.permission === 'granted') {
        new Notification(notification.title || 'Urban Warriors', {
          body: notification.body || 'Tienes una nueva notificación.',
          icon: window.UW_CONFIG.brand.logo,
          data: payload.data || {}
        });
      }
      window.dispatchEvent(new CustomEvent('uw-push-message', { detail: payload }));
    });
    return messaging;
  }

  async function requestPermissionAndToken() {
    if (!configured()) throw new Error('El push remoto se activará al añadir las credenciales de Firebase.');
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') throw new Error('No se concedió permiso para mostrar notificaciones.');
    const { getToken } = await import(`https://www.gstatic.com/firebasejs/${VERSION}/firebase-messaging.js`);
    const instance = await setup();
    const swUrl = new URL('./firebase-messaging-sw.js', location.href);
    const registration = await navigator.serviceWorker.register(swUrl.href, { scope: './firebase-cloud-messaging-push-scope/' });
    const token = await getToken(instance, {
      vapidKey: window.UW_CONFIG.push.vapidKey,
      serviceWorkerRegistration: registration
    });
    if (!token) throw new Error('Firebase no devolvió un token de dispositivo.');
    return token;
  }

  window.UW_PUSH = { configured, requestPermissionAndToken };
})();
