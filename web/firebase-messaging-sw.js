/*
 * Service worker de Firebase Cloud Messaging.
 * Antes de activar push.enabled en config.js, copia aquí el mismo objeto
 * de configuración Firebase. No incluyas service account ni claves privadas.
 */
importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: '',
  authDomain: '',
  projectId: '',
  storageBucket: '',
  messagingSenderId: '',
  appId: ''
};

if (firebaseConfig.apiKey && firebaseConfig.projectId && firebaseConfig.messagingSenderId) {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();
  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    self.registration.showNotification(notification.title || 'Urban Warriors', {
      body: notification.body || 'Tienes una nueva notificación.',
      icon: './assets/icons/icon-192.png',
      badge: './assets/icons/icon-96.png',
      data: payload.data || {}
    });
  });
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification.data?.route || 'notifications';
  event.waitUntil(clients.openWindow(`./#/${route}`));
});
